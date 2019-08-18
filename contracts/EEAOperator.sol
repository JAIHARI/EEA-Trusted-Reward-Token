pragma solidity ^0.5.0;

import "node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./EthereumClaimsRegistry.sol";
import "./EthereumDIDRegistry.sol";
import "./RewardToken.sol";
import "./PenaltyToken.sol";
import "./ReputationToken.sol";

/**
 * @title EEA Operator contract
 */



contract EEAOperator is Ownable {
  using SafeMath for uint256;

  PenaltyToken public penaltyToken;
  RewardToken public rewardToken;
  ReputationToken public reputationToken;
  EthereumDIDRegistry public didRegistry;
  EthereumClaimsRegistry public claimsRegistry;

  address public eeaIssuer; //TODO: Create EEA issuer SC


  event RewardsMinted(
      address indexed account,
      uint256 amount,
      bytes operatorData
  );

  event PenaltiesMinted(
      address indexed account,
      uint256 amount,
      bytes operatorData
  );

  event ReputationMinted(
      address indexed account,
      uint256 amount,
      bytes operatorData
  );

  event PenaltiesBurned(
    address indexed account,
    uint256 amount,
    bytes operatorData
  );

  event RewardsBurned(
    address indexed account,
    uint256 amount,
    bytes operatorData
  );

  event ReputationBurned(
    address indexed account,
    uint256 amount,
    bytes operatorData
  );

  constructor(address _didRegistry,
    address _claimsRegistry,
    address _eeaIssuer) public {

    //set registries and EEA Issuer address
    didRegistry = EthereumDIDRegistry(_didRegistry);
    claimsRegistry = EthereumClaimsRegistry(_claimsRegistry);
    eeaIssuer = _eeaIssuer;
  }

  function registerTokens(address _penaltyToken, address _rewardToken, address _reputationToken)
    external
    onlyOwner
  {
    penaltyToken = PenaltyToken(_penaltyToken);
    rewardToken = RewardToken(_rewardToken);
    reputationToken = ReputationToken(_reputationToken);
  }

  function mintRewards(address account, uint256 amount, bytes calldata operatorData) external onlyOwner
 {
   address organization = didRegistry.identityOwner(account);
   require (_memberCheck(organization), "Error: Not EEA member");

   // Mint reputation for Employee
   reputationToken.operatorMint(account, amount, '', operatorData);

   // Mint for Organizations
   rewardToken.operatorMint(organization, amount, '', operatorData);
   reputationToken.operatorMint(organization, amount, '', operatorData);

   // Emit events
   emit ReputationMinted(account, amount, operatorData);
   emit RewardsMinted(organization, amount, operatorData);
   emit ReputationMinted(organization, amount, operatorData);
 }

 function mintPenalties(address account, uint256 amount, bytes calldata operatorData) external onlyOwner
 {
   // Get Organization
   address organization = didRegistry.identityOwner(account);
   require (_memberCheck(organization), "Error: Not EEA member");

   penaltyToken.operatorMint(organization, amount, '', operatorData);

   // Update user reputation balance
   uint256 reputationBalance = reputationToken.balanceOf(account);
   uint256 reputationPenalty = amount > reputationBalance ? reputationBalance : amount;
   reputationToken.operatorBurn(account, reputationPenalty, '', operatorData);

   // Update org reputation balance
   uint256 orgReputationBalance = reputationToken.balanceOf(organization);
   uint256 orgReputationPenalty = amount > orgReputationBalance ? orgReputationBalance : amount;
   reputationToken.operatorBurn(organization, orgReputationPenalty, '', operatorData);

   //Emit events
   emit PenaltiesMinted(organization, amount, operatorData);
   emit ReputationBurned(organization, orgReputationPenalty, operatorData);
   emit ReputationBurned(account, reputationPenalty, operatorData);
 }

 function burnPenalties(address organization, uint256 amount, bytes memory operatorData)
   public
   onlyOwner
 {
   penaltyToken.operatorBurn(organization, amount, '', operatorData);
   emit PenaltiesBurned(organization, amount, operatorData);
 }

 function burnRewards(address organization, uint256 amount, bytes memory operatorData)
   public
   onlyOwner
 {
   rewardToken.operatorBurn(organization, amount, '', operatorData);
   emit RewardsBurned(organization, amount, operatorData);
 }

 /// At the end of membership year EEA secretary can burn all tokens using them towards membership fee or credits
 /// Reputation tokens stay intact
 function burnAll(address organization)
   external
   onlyOwner
 {
   burnPenalties(organization, penaltyToken.balanceOf(organization), 'membership renewal');
   burnRewards(organization, rewardToken.balanceOf(organization), 'membership renewal');
 }

 function balance(address account)
   external
   view
   returns (uint256, uint256, uint256)
 {
   return (rewardToken.balanceOf(account), penaltyToken.balanceOf(account), reputationToken.balanceOf(account));
 }

 function _memberCheck(address member) internal view returns (bool) {
        bytes32 claim = claimsRegistry.getClaim(msg.sender, member, keccak256(abi.encodePacked("membership")));
        if (claim == keccak256(abi.encodePacked("true"))){
            return true;
        }
    }

}