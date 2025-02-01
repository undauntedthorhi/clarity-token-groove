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
    name: "Test purchasing track and earning points",
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

        // Check earned points
        let userPoints = chain.callReadOnlyFn(
            'token-groove',
            'get-user-points',
            [types.principal(buyer.address)],
            buyer.address
        );
        
        assertEquals(userPoints.result.expectOk(), types.uint(50));
    }
});

Clarinet.test({
    name: "Test streaming and rewards system",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user = accounts.get('wallet_1')!;
        
        // Record multiple streams to accumulate points
        for(let i = 0; i < 10; i++) {
            let block = chain.mineBlock([
                Tx.contractCall('token-groove', 'record-stream', [
                    types.uint(1)
                ], user.address)
            ]);
            block.receipts[0].result.expectOk();
        }
        
        // Check accumulated points (10 streams * 10 points = 100 points)
        let userPoints = chain.callReadOnlyFn(
            'token-groove',
            'get-user-points',
            [types.principal(user.address)],
            user.address
        );
        
        assertEquals(userPoints.result.expectOk(), types.uint(100));
        
        // Check reward tier (should be Bronze - tier 1)
        let rewardTier = chain.callReadOnlyFn(
            'token-groove',
            'get-reward-tier',
            [types.principal(user.address)],
            user.address
        );
        
        assertEquals(rewardTier.result.expectOk(), types.uint(1));
    }
});
