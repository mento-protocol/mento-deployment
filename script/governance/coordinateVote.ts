#!/usr/bin/env node

import { Command } from 'commander';
import { ethers } from 'ethers';
import dotenv from 'dotenv';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

dotenv.config();

// ABI fragments for the governance contracts
const CELO_GOVERNANCE_ABI = [
  'function state(uint256 proposalId) external view returns (uint8)',
  'function proposals(uint256 proposalId) external view returns (uint256 id, address proposer, uint256 eta, uint256 startBlock, uint256 endBlock, uint256 forVotes, uint256 againstVotes, bool canceled, bool executed)'
];

const MENTO_GOVERNOR_ABI = [
  'function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance)',
  'function state(uint256 proposalId) external view returns (uint8)'
];

// Governance proposal states (from OpenZeppelin Governor)
enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated,
  Succeeded,
  Queued,
  Expired,
  Executed
}

interface VoteCoordinationParams {
  // Proposal IDs
  mentoProposalId: string;
  celoProposalId: string;
  // Contract addresses
  celoGovernanceAddress: string;
  mentoGovernorAddress: string;
  // RPC URL
  rpcUrl: string;
  // Multisig details
  address: string;
  derivationPath: string;
}

interface CGPResult {
  passed: boolean;
  executed: boolean;
}

// CLI options interface
interface CommandOptions {
  mentoProposal: string;
  celoProposal: string;
  celoGovernance: string;
  mentoGovernor: string;
  rpcUrl: string;
  address: string;
  derivationPath: string;
}

// Execute celocli command
async function executeCeloCommand(command: string): Promise<string> {
  try {
    const { stdout, stderr } = await execAsync(command);
    if (stderr) {
      console.warn('Command warning:', stderr);
    }
    return stdout.trim();
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to execute celocli command: ${error.message}`);
    }
    throw error;
  }
}

// Main coordination function
async function coordinateVote(params: VoteCoordinationParams): Promise<void> {
  console.log(`Starting vote coordination for CGP ${params.celoProposalId} and MGP ${params.mentoProposalId}`);
  
  try {
    // 1. Verify CGP result
    const cgpResult = await verifyCGPResult(params);
    
    if (!cgpResult.executed) {
      throw new Error('CGP has not been executed yet');
    }

    // 2. Queue corresponding MGP vote based on CGP result
    const voteYes = cgpResult.passed;
    await queueMGPVote({
      ...params,
      vote: voteYes,
    });

    console.log(`Successfully queued ${voteYes ? 'YES' : 'NO'} vote for MGP ${params.mentoProposalId}`);
  } catch (error) {
    console.error('Error in vote coordination:', error);
    throw error;
  }
}

// Verify the result of a Celo Governance Proposal
async function verifyCGPResult(params: VoteCoordinationParams): Promise<CGPResult> {
  const provider = new ethers.JsonRpcProvider(params.rpcUrl);
  const governanceContract = new ethers.Contract(
    params.celoGovernanceAddress,
    CELO_GOVERNANCE_ABI,
    provider
  );

  // Get proposal state and details
  const [proposal, state] = await Promise.all([
    governanceContract.proposals(params.celoProposalId),
    governanceContract.state(params.celoProposalId)
  ]);

  return {
    passed: state === ProposalState.Succeeded || state === ProposalState.Queued || state === ProposalState.Executed,
    executed: state === ProposalState.Executed
  };
}

interface QueueVoteParams extends VoteCoordinationParams {
  vote: boolean;
}

// Queue vote transaction in the multisig
async function queueMGPVote(params: QueueVoteParams): Promise<void> {
  const provider = new ethers.JsonRpcProvider(params.rpcUrl);
  const governorContract = new ethers.Contract(
    params.mentoGovernorAddress,
    MENTO_GOVERNOR_ABI,
    provider
  );

  // Prepare vote transaction data
  const support = params.vote ? 1 : 0;
  const voteData = governorContract.interface.encodeFunctionData('castVote', [params.mentoProposalId, support]);

  // Configure celocli
  await executeCeloCommand(`celocli config:set --node ${params.rpcUrl}`);

  // Submit transaction to multisig
  console.log('\nPreparing multisig transaction:');
  console.log('--------------------------------');
  console.log(`Target: ${params.mentoGovernorAddress} (Mento Governor)`);
  console.log(`Data: ${voteData}`);
  console.log(`Action: Vote ${params.vote ? 'YES' : 'NO'} on MGP ${params.mentoProposalId}`);
  console.log(`Based on: CGP ${params.celoProposalId} ${params.vote ? 'passed' : 'failed'}`);
  console.log('--------------------------------\n');

  const result = await executeCeloCommand(
    `celocli multisig:submitTransaction \
      --from ${params.address} \
      --destination ${params.mentoGovernorAddress} \
      --data ${voteData} \
      --value 0 \
      --derivationPath ${params.derivationPath}`
  );

  // Parse transaction ID from result
  const txIdMatch = result.match(/Transaction ID: (\d+)/);
  const txId = txIdMatch ? txIdMatch[1] : 'unknown';

  console.log('\n✅ Transaction submitted to multisig successfully');
  console.log('------------------------------------------------');
  console.log(`Transaction ID: ${txId}`);
  console.log('\nIMPORTANT INFORMATION FOR APPROVERS:');
  console.log('1. This transaction requires 2 additional approvals within 24 hours');
  console.log('2. Before approving, verify:');
  console.log(`   - The target address matches the Mento Governor: ${params.mentoGovernorAddress}`);
  console.log(`   - The vote matches CGP ${params.celoProposalId} result (${params.vote ? 'YES' : 'NO'})`);
  console.log(`   - The MGP ID is correct: ${params.mentoProposalId}`);
  console.log('\nTo approve, run:');
  console.log(`celocli multisig:approve --tx-id ${txId} --from <YOUR-ADDRESS> --derivationPath <YOUR-PATH>`);
  console.log('\nNote: The transaction will expire if not approved by enough signers within 24 hours');
}

// CLI setup using Commander
const program = new Command();

program
  .name('coordinate-vote')
  .description('Coordinate voting between Celo and Mento governance systems')
  .version('1.0.0')
  .requiredOption('-m, --mento-proposal <id>', 'Mento proposal ID')
  .requiredOption('-c, --celo-proposal <id>', 'Celo proposal ID')
  .requiredOption('-g, --celo-governance <address>', 'Celo Governance contract address')
  .requiredOption('-v, --mento-governor <address>', 'Mento Governor contract address')
  .option('-r, --rpc-url <url>', 'RPC URL', 'https://forno.celo.org')
  .requiredOption('-a, --address <address>', 'Multisig address')
  .requiredOption('-d, --derivation-path <path>', 'Derivation path')
  .action(async (options: CommandOptions) => {
    try {
      await coordinateVote({
        mentoProposalId: options.mentoProposal,
        celoProposalId: options.celoProposal,
        celoGovernanceAddress: options.celoGovernance,
        mentoGovernorAddress: options.mentoGovernor,
        rpcUrl: options.rpcUrl,
        address: options.address,
        derivationPath: options.derivationPath,
      });
    } catch (error: unknown) {
      if (error instanceof Error) {
        console.error('Error:', error.message);
      } else {
        console.error('An unknown error occurred');
      }
      process.exit(1);
    }
  });

program.parse(process.argv); 