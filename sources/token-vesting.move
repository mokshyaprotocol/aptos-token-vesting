module token_vesting::vesting {
    use std::signer;    
    use aptos_framework::account;
    use std::vector;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_std::type_info;
    use aptos_std::simple_map::{Self, SimpleMap};

// All the information required for Vesting
    struct VestingSchedule has key,store
    {
        sender: address,  
        receiver: address, 
        coin_type:address,
        release_times:vector<u64>,   //The times for unlocked
        release_amounts:vector<u64>, //The corresponding amount for getting unlocked
        total_amount:u64,            // Sum of all the release amount   
        resource_cap: account::SignerCapability, // Signer
        released_amount:u64,         //Sum of released amount
    }
    //Map to store seed and corresponding resource account address
    struct VestingCap  has key {
        vestingMap: SimpleMap< vector<u8>,address>,
    }
    //errors
    const ENO_INSUFFICIENT_FUND:u64=0;
    const ENO_NO_VESTING:u64=1;
    const ENO_SENDER_MISMATCH:u64=2;
    const ENO_RECEIVER_MISMATCH:u64=3;
    const ENO_WRONG_SENDER:u64=4;
    const ENO_WRONG_RECEIVER:u64=5;
    //Functions    
    public entry fun create_vesting<CoinType>(
        account: &signer,
        receiver: address,
        release_amounts:vector<u64>,
        release_times:vector<u64>,
        total_amount:u64,
        seeds: vector<u8>
    )acquires VestingCap {
        let account_addr = signer::address_of(account);
        let (vesting, vesting_cap) = account::create_resource_account(account, seeds); //resource account
        let vesting_address = signer::address_of(&vesting);
        if (!exists<VestingCap>(account_addr)) {
            move_to(account, VestingCap { vestingMap: simple_map::create() })
        };
        let maps = borrow_global_mut<VestingCap>(account_addr);
        simple_map::add(&mut maps.vestingMap, seeds,vesting_address);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);
        let length_of_schedule =  vector::length(&release_amounts);
        let length_of_times = vector::length(&release_times);
        assert!(length_of_schedule==length_of_times,ENO_INSUFFICIENT_FUND);
        let i=0;
        let total_amount_required=0;
        while ( i < length_of_schedule )
        {
            let tmp = *vector::borrow(&release_amounts,i);
            total_amount_required=total_amount_required+tmp;
            i=i+1;
        };
        assert!(total_amount_required==total_amount,ENO_INSUFFICIENT_FUND);
        let released_amount=0;
        let coin_address = coin_address<CoinType>();
        move_to(&vesting_signer_from_cap, VestingSchedule{
        sender:account_addr,
        receiver,
        coin_type:coin_address, 
        release_times,
        release_amounts,
        total_amount,
        resource_cap:vesting_cap,
        released_amount,
        });
        let escrow_addr = signer::address_of(&vesting);
        managed_coin::register<CoinType>(&vesting_signer_from_cap); 
        coin::transfer<CoinType>(account, escrow_addr, total_amount);
    }
     public entry fun release_fund<CoinType>(
        receiver: &signer,
        sender: address,
        seeds: vector<u8>
    )acquires VestingSchedule,VestingCap{
        let receiver_addr = signer::address_of(receiver);
        assert!(exists<VestingCap>(sender), ENO_NO_VESTING);
        let maps = borrow_global<VestingCap>(sender);
        let vesting_address = *simple_map::borrow(&maps.vestingMap, &seeds);
        assert!(exists<VestingSchedule>(vesting_address), ENO_NO_VESTING);  
        let vesting_data = borrow_global_mut<VestingSchedule>(vesting_address); 
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_data.resource_cap);
        assert!(vesting_data.sender==sender,ENO_SENDER_MISMATCH);
        assert!(vesting_data.receiver==receiver_addr,ENO_RECEIVER_MISMATCH);
        let length_of_schedule =  vector::length(&vesting_data.release_amounts);
        let i=0;
        let amount_to_be_released=0;
        let now = aptos_framework::timestamp::now_seconds();
        while (i < length_of_schedule)
        {
            let tmp_amount = *vector::borrow(&vesting_data.release_amounts,i);
            let tmp_time = *vector::borrow(&vesting_data.release_times,i);
            if (tmp_time<=now)
            {
                amount_to_be_released=amount_to_be_released+tmp_amount;
            };
            i=i+1;
        };
        amount_to_be_released=amount_to_be_released-vesting_data.released_amount;
        if (!coin::is_account_registered<CoinType>(receiver_addr))
        {managed_coin::register<CoinType>(receiver); 
        };
        coin::transfer<CoinType>(&vesting_signer_from_cap,receiver_addr,amount_to_be_released);
        vesting_data.released_amount=vesting_data.released_amount+amount_to_be_released;
    }
     /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    #[test_only] 
    struct MokshyaMoney { }
    #[test(creator = @0xa11ce, receiver = @0xb0b, token_vesting = @token_vesting)]
   fun test_vesting(
        creator: signer,
        receiver: signer,
        token_vesting: signer
    )acquires VestingSchedule,VestingCap {
       let sender_addr = signer::address_of(&creator);
       let receiver_addr = signer::address_of(&receiver);
        aptos_framework::account::create_account_for_test(sender_addr);
        aptos_framework::account::create_account_for_test(receiver_addr);
        aptos_framework::managed_coin::initialize<MokshyaMoney>(
            &token_vesting,
            b"Mokshya Money",
            b"MOK",
            10,
            true
        );
        // let now  = aptos_framework::timestamp::now_seconds(); // doesn't work in test script
       let release_amounts= vector<u64>[10,20,30];
        //tested with below time as now_seconds doesn't work in test scripts
       let release_times = vector<u64>[10,20,30];
       let total_amount=60;
       aptos_framework::managed_coin::register<MokshyaMoney>(&creator);
       aptos_framework::managed_coin::mint<MokshyaMoney>(&token_vesting,sender_addr,100);    
       create_vesting<MokshyaMoney>(
               &creator,
               receiver_addr,
               release_amounts,
               release_times,
               total_amount,
               b"1bc");
        assert!(
            coin::balance<MokshyaMoney>(sender_addr)==40,
            ENO_WRONG_SENDER,
        );    
        release_fund<MokshyaMoney>(
           &receiver,
           sender_addr,
            b"1bc"
       );
       //tested with now = 25 as it now_seconds doesn't work in test scripts
       assert!(
            coin::balance<MokshyaMoney>(receiver_addr)==30,
            ENO_WRONG_RECEIVER,
        );
   } 

}


