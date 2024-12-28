import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test minting new track",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('token-groove', 'mint-track', [
                types.uint(1),
                types.ascii("Test Track"),
                types.uint(100),
                types.uint(10),
                types.ascii("QmTest123")
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        
        // Verify track info
        let trackInfo = chain.callReadOnlyFn(
            'token-groove',
            'get-track-info',
            [types.uint(1)],
            deployer.address
        );
        
        trackInfo.result.expectSome().expectTuple();
    }
});

Clarinet.test({
    name: "Test purchasing track",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const buyer = accounts.get('wallet_1')!;
        
        // First mint a track
        chain.mineBlock([
            Tx.contractCall('token-groove', 'mint-track', [
                types.uint(1),
                types.ascii("Test Track"),
                types.uint(100),
                types.uint(10),
                types.ascii("QmTest123")
            ], deployer.address)
        ]);
        
        // Then purchase it
        let purchaseBlock = chain.mineBlock([
            Tx.contractCall('token-groove', 'purchase-track', [
                types.uint(1)
            ], buyer.address)
        ]);
        
        purchaseBlock.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Test recording streams",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user = accounts.get('wallet_1')!;
        
        // Record a stream
        let block = chain.mineBlock([
            Tx.contractCall('token-groove', 'record-stream', [
                types.uint(1)
            ], user.address)
        ]);
        
        block.receipts[0].result.expectOk();
        
        // Check stream count
        let streamCount = chain.callReadOnlyFn(
            'token-groove',
            'get-stream-count',
            [types.uint(1)],
            user.address
        );
        
        assertEquals(streamCount.result.expectOk(), types.uint(1));
    }
});