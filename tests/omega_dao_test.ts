import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that proposal submission works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const researcher = accounts.get('wallet_1')!;
    
    // First mint some tokens for the researcher
    let block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'mint', [
        types.uint(2000),
        types.principal(researcher.address)
      ], deployer.address)
    ]);
    
    // Submit proposal
    block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'submit-proposal', [
        types.ascii("Cancer Research Project"),
        types.utf8("Research into novel cancer treatments"),
        types.uint(50000)
      ], researcher.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(0);
  },
});

Clarinet.test({
  name: "Test voting mechanism",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const voter1 = accounts.get('wallet_1')!;
    const voter2 = accounts.get('wallet_2')!;
    
    // Setup: mint tokens and create proposal
    let block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'mint', [
        types.uint(600000),
        types.principal(voter1.address)
      ], deployer.address),
      Tx.contractCall('omega-dao', 'mint', [
        types.uint(400000),
        types.principal(voter2.address)
      ], deployer.address),
      Tx.contractCall('omega-dao', 'submit-proposal', [
        types.ascii("Important Research"),
        types.utf8("Description"),
        types.uint(10000)
      ], voter1.address)
    ]);
    
    // Vote
    block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'vote', [
        types.uint(0),
        types.bool(true)
      ], voter1.address),
      Tx.contractCall('omega-dao', 'vote', [
        types.uint(0),
        types.bool(false)
      ], voter2.address)
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk().expectBool(true);
    });
  },
});

Clarinet.test({
  name: "Test proposal execution",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const researcher = accounts.get('wallet_1')!;
    const voter = accounts.get('wallet_2')!;
    
    // Setup and voting
    let block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'mint', [
        types.uint(1000000),
        types.principal(voter.address)
      ], deployer.address),
      Tx.contractCall('omega-dao', 'submit-proposal', [
        types.ascii("Research Project"),
        types.utf8("Description"),
        types.uint(5000)
      ], researcher.address)
    ]);
    
    // Vote
    block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'vote', [
        types.uint(0),
        types.bool(true)
      ], voter.address)
    ]);
    
    // Mine blocks to pass voting period
    chain.mineEmptyBlockUntil(200);
    
    // Execute proposal
    block = chain.mineBlock([
      Tx.contractCall('omega-dao', 'execute-proposal', [
        types.uint(0)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
  },
});