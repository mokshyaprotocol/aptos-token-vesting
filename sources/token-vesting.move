module token_vesting::acl_based_mb {
    use std::string::String;
    use std::signer;    
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::account;
    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::coin::{Self};

    struct VestingSchedule<phantom CoinType> has key,store{
        sender: address,
        receiver: address,
        vested_amount: u64,
        unlock_time: u64,
        coin_type:coin::Coin<CoinType>,
        schedule: vector<Schedule>,
        total_amount:u64,
        resource_cap: account::SignerCapability
    }
    struct Schedule has store{
        time:u64,
        amount:u64,
    }

    public entry fun create_vesting<CoinType>(
        account: &signer,
        receiver: address,
        vested_amount: u64,
        unlock_time: u64,
        schedule: vector<Schedule>,
        total_amount:u64,
        seeds: vector<u8>
    ){
        let account_addr = signer::address_of(account);
        let (vesting, vesting_cap) = account::create_resource_account(account, seeds);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);
        move_to(&vesting_signer_from_cap, VestingSchedule<CoinType>{
        sender:account_addr,
        receiver,
        vested_amount,
        unlock_time,
        coin_type:Coin<CoinType>, // need to store coin type or coin address to validate the token 
        schedule,
        total_amount,
        resource_cap:vesting_cap
        });
        // let escrow_addr = signer::address_of(&vesting); 
        // coin::transfer<CoinType>(account, escrow_addr, amount);
    }
}