pragma solidity ^0.4.25;
import "./Owner.sol";

interface ICoin4You{
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
}

contract Marketing is Owner{
    
    uint8 public decimals = 18;
    
    address c4yCoinAddress=0x5e72914535f202659083db3a02c984188fa26e9f;
    
    mapping(address => mapping(address => bool)) recommendLogs;
    bool public isRecommendReward=true;
    uint public recommendRewardAmt=20000;
    
    mapping(address => bool) freeRewardLogs;
    bool public isFreeReward=true;
    uint public freeRewardRewardAmt=10000;
    
    function setReward(bool _isRecommendReward,uint _recommendRewardAmt,bool _isFreeReward,uint _freeRewardRewardAmt)public onlyOwner{
        isRecommendReward=_isRecommendReward;
        recommendRewardAmt=_recommendRewardAmt;
        isFreeReward=_isFreeReward;
        freeRewardRewardAmt=_freeRewardRewardAmt;
    }
    
    function recommendReward(address recommendAddress)public {
        require(isRecommendReward==true,"RecommendReward end");
        require(msg.sender!=recommendAddress,"you can not recommend yourself");
        require(recommendLogs[recommendAddress][msg.sender]==false && recommendLogs[msg.sender][recommendAddress]==false,"this pair address already use");
        ICoin4You c4y=ICoin4You(c4yCoinAddress);
        c4y.transferFrom(owner,recommendAddress,recommendRewardAmt * 10 ** uint256(decimals));
        c4y.transferFrom(owner,msg.sender,recommendRewardAmt * 10 ** uint256(decimals));
        recommendLogs[recommendAddress][msg.sender]=true;
        recommendLogs[msg.sender][recommendAddress]==true;
    }
    
    function freeReward()public{
        
        require(isFreeReward==true,"freeReward end");
        require(freeRewardLogs[msg.sender]==false,"you are already got");
        ICoin4You c4y=ICoin4You(c4yCoinAddress);
        c4y.transferFrom(owner,msg.sender,freeRewardRewardAmt * 10 ** uint256(decimals));
        freeRewardLogs[msg.sender]=true;
        
    }
    
    
    
    
}