module token_vesting::acl_based_mb {
    use std::signer;    
    use aptos_framework::account;
    use aptos_framework::timestamp::now_seconds;
    use std::vector;
    use aptos_framework::aggregator_factory;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_std::type_info;
    struct VestingSchedule has key,store
    {
        sender: address,
        receiver: address,
        coin_type:address,
        release_times:vector<u64>,
        release_amounts:vector<u64>,
        total_amount:u64,
        resource_cap: account::SignerCapability,
        released_amount:u64,
    }
    //errors
    const ENO_INSUFFICIENT_FUND:u64=0;
    const ENO_NO_VESTING:u64=1;
    const ENO_SENDER_MISMATCH:u64=2;
    const ENO_RECEIVER_MISMATCH:u64=3;

    public entry fun create_vesting<CoinType>(
        account: &signer,
        receiver: address,
        release_amounts:vector<u64>,
        release_times:vector<u64>,
        total_amount:u64,
        seeds: vector<u8>
    ){
        let account_addr = signer::address_of(account);
        let (vesting, vesting_cap) = account::create_resource_account(account, seeds);
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

        let length_of_schedule =  vector::length(&vesting_data.release_amounts);
        let i=0;
        let amount_to_be_released=0;
        let now = now_seconds();
        while (i < length_of_schedule)
        {
            let tmp_amount = *vector::borrow(&vesting_data.release_amounts,i);
            let tmp_time = *vector::borrow(&vesting_data.release_times,i);
            if (tmp_time>=now)
            {
                amount_to_be_released=amount_to_be_released+tmp_amount;
            };
            i=i+1;
        };
        amount_to_be_released=amount_to_be_released-vesting_data.released_amount;
        managed_coin::register<CoinType>(receiver); 
        coin::transfer<CoinType>(&vesting_signer_from_cap,receiver_addr,amount_to_be_released);
    }

     /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    #[test_only] 
   struct MokshyaCoin { }
   #[test(creator = @0xa11ce, receiver = @0xa11ce,framework= @0x1)]
   fun test_create_vesting(creator: &signer,receiver:&signer,framework:&signer) acquires VestingSchedule{
       account::create_account_for_test(signer::address_of(creator));
       account::create_account_for_test(signer::address_of(receiver));
    //    account::create_account_for_test(signer::address_of(&framework));
       let receiver_addr = signer::address_of(receiver); 
       let sender_addr = signer::address_of(creator);   
       let now = now_seconds();
       let release_amounts= vector<u64>[10,20,30];
       let release_times = vector<u64>[10,20,30];
       let total_amount=60;
 
    //    aggregator_factory::initialize_aggregator_factory_for_test(&framework);
       managed_coin::initialize<MokshyaCoin>(
           creator,
           b"Mokshya Coin",
           b"Mokshya",
           6,
           false,
       );
       managed_coin::register<MokshyaCoin>(creator);
       managed_coin::mint<MokshyaCoin>(creator,sender_addr,100);    
       create_vesting<MokshyaCoin>(
               creator,
               receiver_addr,
               release_amounts,
               release_times,
               total_amount,
               b"1bc");
      release_fund<MokshyaCoin>(
           receiver,
           sender_addr,
           b"1bc"
       );
   } 

}


