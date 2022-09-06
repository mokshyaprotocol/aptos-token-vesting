module token_vesting::acl_based_mb {
    use std::string::String;
    use std::signer;    
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::account;
    use aptos_framework:: now_seconds;
    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::coin::{Self};

    struct VestingSchedule<phantom CoinType> has key,store{
        sender: address,
        receiver: address,
        unlock_time: u64,
        coin_type:coin::Coin<CoinType>,
        schedule: vector<Schedule>,
        total_amount:u64,
        resource_cap: account::SignerCapability,
        released_amount:u64,
    }
    struct Schedule has store{
        release_time:u64,
        release_amount:u64,
    }
    //errors
    const ENO_INSUFFICIENT_FUND=0;
    const ENO_NO_VESTING=1;
    const ENO_SENDER_MISMATCH=2;
    const ENO_RECEIVER_MISMATCH=3;
    public entry fun create_vesting<CoinType>(
        account: &signer,
        receiver: address,
        schedule: vector<Schedule>,
        total_amount:u64,
        seeds: vector<u8>
    ){
        let account_addr = signer::address_of(account);
        let (vesting, vesting_cap) = account::create_resource_account(account, seeds);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);
        let length_of_schedule =  Vector::length(&schedule);
        let i=0;
        let total_amount_required=0;
        while (i<length_of_schedule)
        {
            total_amount_required+=schedule[i].release_amount;
            i+=1;
        }
        assert!(total_amount_required>total_amount,ENO_INSUFFICIENT_FUND);
        let released_amount=0;
        move_to(&vesting_signer_from_cap, VestingSchedule<CoinType>{
        sender:account_addr,
        receiver,
        release_amount,
        unlock_time,
        coin_type:Coin<CoinType>, // need to store coin type or coin address to validate the token 
        schedule,
        total_amount,
        resource_cap:vesting_cap
        });
        let escrow_addr = signer::address_of(&vesting); 
        coin::transfer<CoinType>(account, escrow_addr, amount);

    }
     public entry fun release_fund<CoinType>(
        receiver: &signer,
        sender: address,
        seeds: vector<u8>,
    ){
        let receiver_addr = signer::address_of(receiver);        
        let (vesting, vesting_cap) = account::create_resource_account(sender, seeds);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);

        assert!(exists<VestingSchedule>(&vesting_signer_from_cap), ENO_NO_VESTING);
     
        let vesting_data = borrow_global<VestingSchedule>(&vesting_signer_from_cap); 
        assert!(vesting_data.sender==sender,ENO_SENDER_MISMATCH);
        assert!(vesting_data.receiver==receiver,ENO_RECEIVER_MISMATCH);

        let length_of_schedule =  Vector::length(&schedule);
        let i=0;
        let amount_to_be_released=0;
        let now = now_seconds();
        while (i<length_of_schedule)
        {
            if (vesting_data[i].release_time>=now)
            {
                amount_to_be_released+=vesting_data[i].release_amount;
            }
            i+=1;
        }
        amount_to_be_released-=vesting_data.released_amount;
        let escrow_addr = signer::address_of(&vesting); 
        coin::transfer<CoinType>(&vesting_signer_from_cap,receiver_addr,amount_to_be_released);
    }
}