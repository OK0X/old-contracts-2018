pragma solidity ^0.4.25;

contract Owner{
    
    address public owner;
    
    uint public ownerIncome;
    
    constructor()public {
        owner=msg.sender;
    }
    
    modifier onlyOwner(){
        
        require(msg.sender == owner,"you are not the owner");
        _;
    }
    
    function transferOwnership(address newOwner)public onlyOwner{
     
        owner = newOwner;
    }
    
    function ownerWithDraw()public onlyOwner{
        owner.transfer(ownerIncome);
        ownerIncome=0;
    }
}