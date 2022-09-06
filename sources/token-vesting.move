module token_vesting::acl_based_mb {
    //use std::string::String;
    use std::signer;    
    //use std::option::{Self, Option};
    use aptos_framework::account;
     use aptos_framework::timestamp::now_seconds;
    use std::vector;

   // use aptos_std::event::{Self, EventHandle};
    use aptos_framework::coin::{Self};
    struct VestingSchedule has key,store{
        sender: address,
        receiver: address,
        // coin_type:coin::Coin<CoinType>,
        schedule: vector<Schedule>,
        total_amount:u64,
        resource_cap: account::SignerCapability,
        released_amount:u64,
    }
    struct Schedule has store,copy{
        release_time:u64,
        release_amount:u64,
    }
    //errors
    const ENO_INSUFFICIENT_FUND:u64=0;
    const ENO_NO_VESTING:u64=1;
    const ENO_SENDER_MISMATCH:u64=2;
    const ENO_RECEIVER_MISMATCH:u64=3;
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
        let length_of_schedule =  vector::length(&schedule);
        let i=0;
        let total_amount_required=0;
        while ( i < length_of_schedule )
        {
            let tmp = vector::borrow<Schedule>(&schedule,i);
            total_amount_required=total_amount_required+tmp.release_amount;
            i=i+1;
        };
        assert!(total_amount_required>total_amount,ENO_INSUFFICIENT_FUND);
        let released_amount=0;
        move_to(&vesting_signer_from_cap, VestingSchedule{
        sender:account_addr,
        receiver,
        // coin_type:Coin<CoinType>, 
        schedule,
        total_amount,
        resource_cap:vesting_cap,
        released_amount,
        });
        let escrow_addr = signer::address_of(&vesting); 
        coin::transfer<CoinType>(account, escrow_addr, total_amount);

    }
     public entry fun release_fund<CoinType>(
        receiver: &signer,
        sender: address,
        seeds: vector<u8>,
    )acquires VestingSchedule{
        let receiver_addr = signer::address_of(receiver);        
        let (vesting, vesting_cap) = account::create_resource_account(receiver, seeds);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);
        let vesting_address = signer::address_of(&vesting);
        assert!(exists<VestingSchedule>(vesting_address), ENO_NO_VESTING);
     
        let vesting_data = borrow_global<VestingSchedule>(vesting_address); 
        assert!(vesting_data.sender==sender,ENO_SENDER_MISMATCH);
        assert!(vesting_data.receiver==receiver_addr,ENO_RECEIVER_MISMATCH);

        let length_of_schedule =  vector::length<Schedule>(&vesting_data.schedule);
        let i=0;
        let amount_to_be_released=0;
        let now = now_seconds();
        while (i < length_of_schedule)
        {
            let tmp = vector::borrow<Schedule>(&vesting_data.schedule,i);
            if (tmp.release_time>=now)
            {
                amount_to_be_released=amount_to_be_released+tmp.release_amount;
            };
            i=i+1;
        };
        amount_to_be_released=amount_to_be_released-vesting_data.released_amount;
        //let escrow_addr = signer::address_of(&vesting); 
        coin::transfer<CoinType>(&vesting_signer_from_cap,receiver_addr,amount_to_be_released);
    }
}