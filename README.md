Mokshya Protocol's token vesting contract to vest tokens as per your need on the Aptos Blockchain.
# Cloning the repository

``` git clone https://github.com/mokshyaprotocol/aptos-token-vesting ```

Change the file path in dependencies and update the addresses 

# Compile

``` aptos move compile --named-addresses token_vesting::acl_based_mb=<YOUR ADDRESS> ```

# Test

``` aptos move test ```

# Publish

```aptos move publish --named-addresses token_vesting::acl_based_mb=<YOUR ADDRESS> ```

# Update program address

Update program address inside tests **vesting.ts** 

# Run test

```yarn test```

# Contributions

Please review [CONTRIBUTING.md](./CONTRIBUTING.md) for more information.
