import hre, { ethers } from "hardhat";
import { expect } from "chai";

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
export const ZERO_ADDRESS_BYTES32 = ethers.constants.HashZero;

export const getTypedMessage = (
  nonce: any,
  address: string,
  functionSignature: string,
  contractAddress: string,
  chainId: number,
  domainName: string,
  domainVersion: string
): TypedMessage => ({
  domain: {
    name: domainName,
    version: domainVersion,
    salt: chainId,
    verifyingContract: contractAddress,
  },
  primaryType: "MetaTransaction",
  types: {
    EIP712Domain: [
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "salt", type: "uint256" },
      { name: "verifyingContract", type: "address" },
    ],
    MetaTransaction: [
      { name: "nonce", type: "uint256" },
      { name: "from", type: "address" },
      { name: "functionSignature", type: "bytes" },
    ],
  },
  message: {
    nonce: parseInt(nonce),
    from: address,
    functionSignature,
  },
});

export const getRSV = (
  signature: string
): { r: string; s: string; v: string } => {
  const sig = signature.substring(2);
  const r = "0x" + sig.substring(0, 64);
  const s = "0x" + sig.substring(64, 128);
  const v = parseInt(sig.substring(128, 130), 16).toString();
  return { r, s, v };
};

export type TypedMessage = {
  domain: {
    name: string;
    version: string;
    /*chainId: number;*/ salt: number;
    verifyingContract: string;
  };
  primaryType: string;
  types: {
    EIP712Domain: { name: string; type: string }[];
    MetaTransaction: { name: string; type: string }[];
  };
  message: { nonce: number; from: string; functionSignature: string };
};

export const timeTravel = async (timestamp: Number) => {
  await hre.network.provider.send("evm_setNextBlockTimestamp", [
    timestamp,
  ]);
  await hre.network.provider.send("evm_mine");
  expect(
    (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
      .timestamp
  ).to.equal(timestamp);
}

export const resetNetwork = async () => {
  await hre.network.provider.request({
    method: "hardhat_reset",
    params: [],
  });
}
