// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IMerkleDistributor } from "merkle-distributor/interfaces/IMerkleDistributor.sol";

error EndTimeInPast();
error ClaimWindowFinished();
error NoWithdrawDuringClaim();
error AlreadyClaimed();
error InvalidProof();

contract MerkleDistributor is IMerkleDistributor {
  using SafeERC20 for IERC20;

  address public immutable override token;
  bytes32 public immutable override merkleRoot;

  // This is a packed array of booleans.
  mapping(uint256 => uint256) private claimedBitMap;

  constructor(address token_, bytes32 merkleRoot_) {
    token = token_;
    merkleRoot = merkleRoot_;
  }

  function isClaimed(uint256 index) public view virtual override returns (bool) {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    uint256 claimedWord = claimedBitMap[claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  function _setClaimed(uint256 index) private {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
  }

  function claim(
    uint256 index,
    address account,
    uint256 amount,
    bytes32[] calldata merkleProof
  ) public virtual override {
    if (isClaimed(index)) revert AlreadyClaimed();

    // Verify the merkle proof.
    bytes32 node = keccak256(abi.encodePacked(index, account, amount));
    if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

    // Mark it claimed and send the token.
    _setClaimed(index);
    IERC20(token).safeTransfer(account, amount);

    emit Claimed(index, account, amount);
  }
}

contract MerkleDistributorWithDeadline is MerkleDistributor, Ownable {
  using SafeERC20 for IERC20;

  uint256 public immutable endTime;

  constructor(address token_, bytes32 merkleRoot_, uint256 endTime_) MerkleDistributor(token_, merkleRoot_) {
    if (endTime_ <= block.timestamp) revert EndTimeInPast();
    endTime = endTime_;
  }

  function claim(
    uint256 index,
    address account,
    uint256 amount,
    bytes32[] calldata merkleProof
  ) public virtual override {
    if (block.timestamp > endTime) revert ClaimWindowFinished();
    super.claim(index, account, amount, merkleProof);
  }

  function withdraw() external onlyOwner {
    if (block.timestamp < endTime) revert NoWithdrawDuringClaim();
    IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
  }
}

contract TestingMerkleDistributor is MerkleDistributorWithDeadline {
  // This is a packed array of booleans.
  mapping(uint256 => uint256) private claimedBitMap;

  constructor(
    address token_,
    bytes32 merkleRoot_,
    uint256 endTime_
  ) MerkleDistributorWithDeadline(token_, merkleRoot_, endTime_) {}

  function setClaimed(uint256 index, bool claimed) public onlyOwner {
    _setClaimed(index, claimed);
  }

  function _setClaimed(uint256 index, bool claimed) public {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    if (claimed) {
      claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    } else {
      claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] & ~(1 << claimedBitIndex);
    }
  }

  function isClaimed(uint256 index) public view virtual override returns (bool) {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    uint256 claimedWord = claimedBitMap[claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  function claim(
    uint256 index,
    address account,
    uint256 amount,
    bytes32[] calldata merkleProof
  ) public virtual override {
    super.claim(index, account, amount, merkleProof);
    _setClaimed(index, true);
  }
}
