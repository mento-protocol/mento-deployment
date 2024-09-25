// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import { MerkleDistributorWithDeadline } from "merkle-distributor/MerkleDistributorWithDeadline.sol";

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
