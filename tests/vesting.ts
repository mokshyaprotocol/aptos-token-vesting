//Testing Vesting Contract
import dotenv from "dotenv";
dotenv.config();

import { AptosClient, AptosAccount, FaucetClient, BCS, TxnBuilderTypes, } from "aptos";
import { aptosCoinStore } from "./common";
import assert from "assert";
import console from "console";
import { describe, it } from "node:test";


const NODE_URL = process.env.APTOS_NODE_URL || "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = process.env.APTOS_FAUCET_URL || "https://faucet.devnet.aptoslabs.com";

const {
  AccountAddress,
  TypeTagStruct,
  EntryFunction,
  StructTag,
  TransactionPayloadEntryFunction,
  RawTransaction,
  ChainId,
} = TxnBuilderTypes;
const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);

// Sender Account
const account1 = new AptosAccount();
// Receiver Account
const account2 = new AptosAccount();
/**
 * Testing Vesting Contract
 */
 describe("Token Vesting", () => {
  it("Create Vesting", async () => {
  await faucetClient.fundAccount(account1.address(), 100000);//Airdropping
  let resources = await client.getAccountResources(account1.address());
  let accountResource = resources.find((r) => r.type === aptosCoinStore);
  let balance = parseInt((accountResource?.data as any).coin.value);
  assert(balance === 100000); //Verify the balance of Account 1
  //Time and Amounts
  const now = Math.floor(Date.now() / 1000)
  const release_amount =[20, 30, 40, 50];
  const release_time_increment =[ 15, 20, 30];
  var release_time:BigInt[]=[BigInt(now)]
  release_time_increment.forEach((item) => {
    let val=BigInt(now+item);
    release_time.push(val);
  });
//Aptos Coin Type, Can be used with other coin types as well
  const token = new TypeTagStruct(StructTag.fromString("0x1::aptos_coin::AptosCoin"));
//Payload for creating Vesting
  const entryFunctionPayload = new TransactionPayloadEntryFunction(
    EntryFunction.natural(
      // Fully qualified module name, `AccountAddress::ModuleName`
      "0x5afd8bcbb3d4271d3a05ff958fcf69c011be9faf6d41fcd2c5e6d12910f255bb::acl_based_mb",
      // Module function
      "create_vesting",
      // The coin type to transfer
      [token],
      // Arguments receiver account address, release amount, release times, total amount, seeds
      [BCS.bcsToBytes(AccountAddress.fromHex(account2.address())), BCS.serializeVectorWithFunc(release_amount,"serializeU64"), BCS.serializeVectorWithFunc(release_time,"serializeU64"),BCS.bcsSerializeUint64(140),BCS.bcsSerializeStr("ABC")],
    ),
  );
  const [{ sequence_number: sequenceNumber }, chainId] = await Promise.all([
    client.getAccount(account1.address()),
    client.getChainId(),
  ]);
  const rawTxn = new RawTransaction(
    // Transaction sender account address
    AccountAddress.fromHex(account1.address()),
    BigInt(sequenceNumber),
    entryFunctionPayload,
    // Max gas unit to spend
    BigInt(2000),
    // Gas price per unit
    BigInt(1),
    // Expiration timestamp. Transaction is discarded if it is not executed within 10 seconds from now.
    BigInt(Math.floor(Date.now() / 1000) + 90),
    new ChainId(chainId),
  );

  // Sign the raw transaction with account1's private key
  const bcsTxn = await AptosClient.generateBCSTransaction(account1, rawTxn);
  const transactionRes = await client.submitSignedBCSTransaction(bcsTxn);
  await client.waitForTransaction(transactionRes.hash);
  console.log("CreateVesting",transactionRes.hash);
  });
  it("Release fund", async () => {
   //Receiver Account  
  await faucetClient.fundAccount(account2.address(), 10000);
  let resources = await client.getAccountResources(account2.address());
  let accountResource = resources.find((r) => r.type === aptosCoinStore);
  let balance = parseInt((accountResource?.data as any).coin.value);
  assert(balance === 10000);//Verifying Balances
  const token = new TypeTagStruct(StructTag.fromString("0x1::aptos_coin::AptosCoin"));
  //Payload for receiving Vesting
  const entryFunctionPayload = new TransactionPayloadEntryFunction(
    EntryFunction.natural(
      // Fully qualified module name, `AccountAddress::ModuleName`
      "0x5afd8bcbb3d4271d3a05ff958fcf69c011be9faf6d41fcd2c5e6d12910f255bb::acl_based_mb",
      // Module function
      "release_fund",
      // The coin type to transfer
      [token],
      // Arguments sender account address, seeds
      [BCS.bcsToBytes(AccountAddress.fromHex(account1.address())),BCS.bcsSerializeStr("ABC")],
    ),
  );
  const [{ sequence_number: sequenceNumber }, chainId] = await Promise.all([
    client.getAccount(account2.address()),
    client.getChainId(),
  ]);
  const rawTxn = new RawTransaction(
    // Transaction receiver account address
    AccountAddress.fromHex(account2.address()),
    BigInt(sequenceNumber),
    entryFunctionPayload,
    // Max gas unit to spend
    BigInt(2000),
    // Gas price per unit
    BigInt(1),
    // Expiration timestamp. Transaction is discarded if it is not executed within 10 seconds from now.
    BigInt(Math.floor(Date.now() / 1000) + 10),
    new ChainId(chainId),
  );
  // Sign the raw transaction with account1's private key
  const bcsTxn = await AptosClient.generateBCSTransaction(account2, rawTxn);
  const transactionRes2 = await client.submitSignedBCSTransaction(bcsTxn);
  await client.waitForTransaction(transactionRes2.hash);
  console.log("Release Fund",transactionRes2.hash);
  });
});
