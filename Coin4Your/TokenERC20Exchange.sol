pragma solidity ^0.4.25;
import "./Owner.sol";

interface ITokenERC20{
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
}

contract TokenERC20Exchange is Owner{
    
    uint8 public decimals = 18;
    address tokenAddress=0x066771118888B07539988963e29fFe99d6E62fD1;
    
    ITokenERC20 tokenERC20= ITokenERC20(tokenAddress);
    
    //c4y-eth exchange
    uint8 constant OSMaking=0;
    uint8 constant OSCanceled=1;
    uint8 constant OSFinished=2;
    
    uint8 public c4yExchangeFeeRatio=2;
    uint public exchangeMaxETH=1000 ether;
    uint public exchangeMaxC4Y=10000000;
    
    event CancelOrderEvent(address indexed maker,uint orderid);
    event ModifyOrderEvent(address indexed maker,uint id,uint amtMin,uint amtMax,uint price);
    event TakeOrderEvent(address indexed maker,uint orderid,uint amt,uint price,uint time,address indexed taker);
    
    //sell c4y
    struct SellC4YOrder{
        address maker;
        uint amtMin;
        uint amtMax;
        uint amtLeft;
        uint price;
        uint8 orderStatus;
    }
    
    SellC4YOrder[] sellC4YOrders;
    
    event MakeSellC4YOrderEvent(address indexed maker,uint amtMin,uint amtMax,uint price,uint orderid);
    
    
    //buy c4y
    struct BuyC4YOrder{
        address maker;
        uint amtMin;
        uint amtMax;
        uint amtLeft;
        uint price;
        uint8 orderStatus;
    }
    
    BuyC4YOrder[] buyC4YOrders;
    
    event MakeBuyC4YOrderEvent(address indexed maker,uint amtMin,uint amtMax,uint price,uint orderid);
    
    function setC4YExchangeFee(uint8 _feeratio,uint _maxeth,uint _maxc4y)public onlyOwner{
        c4yExchangeFeeRatio=_feeratio;
        exchangeMaxETH=_maxeth;
        exchangeMaxC4Y=_maxc4y;
    }
    
    modifier orderCheck(uint _amtMin,uint _amtMax,uint _price){
        require((_amtMin > 0) && (_amtMin < _amtMax) && (_amtMax <= exchangeMaxC4Y) ,"amt value is not right");
        require((_price > 0) && (_price * _amtMax <= exchangeMaxETH),"price value is not right ");
        _;
        
    }
    
 
    //only token contract can call it 
    function toMakeSellOrder(address _from, uint256 _value, address _token, uint _amtMin,uint _amtMax,uint _price)external orderCheck(_amtMin,_amtMax,_price){
        
        require(_token==tokenAddress && msg.sender==tokenAddress ,"token address is not right");
        require( _value==_amtMax * 10 ** uint256(decimals),"value is not right");
        
        if(tokenERC20.transferFrom(_from,address(this),_value)){
            uint id=sellC4YOrders.push(SellC4YOrder(_from,_amtMin,_amtMax,_amtMax,_price,OSMaking));
            emit MakeSellC4YOrderEvent(_from,_amtMin,_amtMax,_price,id);
        }
        
        
        
    }
    
    function cancelSellOrder(uint id)public {
        SellC4YOrder storage sellOrder=sellC4YOrders[id];
        require(sellOrder.maker==msg.sender,"it is not your order");
        require(OSMaking==sellOrder.orderStatus,"it already canceled");
        
        if(tokenERC20.transfer(msg.sender,sellOrder.amtLeft * 10 ** uint256(decimals))){
            sellOrder.orderStatus=OSCanceled;
            emit CancelOrderEvent(msg.sender,id);
        }
        
    }
    
 
    
    //only token contract can call it 
    function toModifySellOrder(address _from, uint256 _value, address _token, uint _id,uint _amtMin,uint _amtMax,uint _price)external orderCheck(_amtMin,_amtMax,_price){
        SellC4YOrder storage sellOrder=sellC4YOrders[_id];
        
        require(_token==tokenAddress && msg.sender==tokenAddress,"token address is not right");
        require(sellOrder.maker==_from ,"it is not your order");
        require(OSMaking==sellOrder.orderStatus,"the order is cancel");
        
        if(sellOrder.amtLeft > _amtMax){
            
            if(tokenERC20.transfer(_from,(sellOrder.amtLeft-_amtMax) * 10 ** uint256(decimals))){
                doModify(_from,_id,_amtMin,_amtMax,_price);
            }
        }else{
            require(_value==(_amtMax-sellOrder.amtLeft) * 10 ** uint256(decimals),"value is not right");
            
            if(tokenERC20.transferFrom(_from,address(this),_value)){
                doModify(_from,_id,_amtMin,_amtMax,_price);
            }
        }
        
        
    }
    
    
    function doModify(address _from,uint _id,uint _amtMin,uint _amtMax,uint _price)private{
        SellC4YOrder storage sellOrder=sellC4YOrders[_id];
        sellOrder.amtMin=_amtMin;
        sellOrder.amtMax=_amtMax;
        sellOrder.amtLeft=_amtMax;
        sellOrder.price=_price;
        
        emit ModifyOrderEvent(_from,_id,_amtMin,_amtMax,_price);
    }
    
    
    function takeSellOrder(uint id,uint takeAmt)public payable{
        
        SellC4YOrder storage sellOrder=sellC4YOrders[id];
        require(sellOrder.orderStatus==OSMaking,"order is cancel");
        require(sellOrder.amtLeft >= takeAmt,"leftamt is not enough");
        require(takeAmt >= sellOrder.amtMin,"takeamt should bigger >= minamt");
        require((sellOrder.price * takeAmt) == msg.value,"you must set the right price");
        
        uint newincome=msg.value * (1000-c4yExchangeFeeRatio)/1000;
        ownerIncome += (msg.value-newincome);
        sellOrder.maker.transfer(newincome);
        
        tokenERC20.transfer(msg.sender,takeAmt * 10 ** uint256(decimals));
        
        sellOrder.amtLeft -= takeAmt;
            
        emit TakeOrderEvent(sellOrder.maker,id,takeAmt,sellOrder.price,now,msg.sender);
        
    }
    
    function getSellOrderInfoById(uint id)public view returns(uint amtLeft,uint price,uint8 status,uint min){
        
        SellC4YOrder storage sellOrder=sellC4YOrders[id];
        return (sellOrder.amtLeft,sellOrder.price,sellOrder.orderStatus,sellOrder.amtMin);
    }
    
    //buy c4y
    function makeBuyC4YOrder(uint _amtMin,uint _amtMax,uint _price)public payable orderCheck(_amtMin,_amtMax,_price) {
        require(msg.value==_price * _amtMax,"you should desposit eth first");
        
        uint id=buyC4YOrders.push(BuyC4YOrder(msg.sender,_amtMin,_amtMax,_amtMax,_price,OSMaking));
        emit MakeBuyC4YOrderEvent(msg.sender,_amtMin,_amtMax,_price,id);
    }
    
    function cancelBuyOrder(uint id)public {
        BuyC4YOrder storage buyOrder=buyC4YOrders[id];
        require(buyOrder.maker==msg.sender,"it is not your order");
        require(OSMaking==buyOrder.orderStatus,"it already canceled");
        buyOrder.orderStatus=OSCanceled;
        
        msg.sender.transfer(buyOrder.price * buyOrder.amtLeft);
        emit CancelOrderEvent(msg.sender,id);
    }
    
    function modifyBuyOrder(uint id,uint _amtMin,uint _amtMax,uint _price)public payable orderCheck(_amtMin,_amtMax,_price) {
        BuyC4YOrder storage buyOrder=buyC4YOrders[id];
        require(buyOrder.maker==msg.sender ,"it is not your order");
        require(OSMaking==buyOrder.orderStatus," the order is cancel");
        
        if(buyOrder.amtLeft*buyOrder.price > _amtMax*_price){
            msg.sender.transfer(buyOrder.amtLeft*buyOrder.price-_amtMax*_price);
        }else{
            require(msg.value==(_amtMax*_price-buyOrder.amtLeft*buyOrder.price),"you should add eth");
        }
        
        buyOrder.amtMin=_amtMin;
        buyOrder.amtMax=_amtMax;
        buyOrder.amtLeft=_amtMax;
        buyOrder.price=_price;
        
        emit ModifyOrderEvent(msg.sender,id,_amtMin,_amtMax,_price);
        
    }
    

    
    //only token contract can call it 
    function toTakeBuyOrder(address _from, uint256 _value, address _token, uint _id,uint takeAmt)external {
        require(_token==tokenAddress && msg.sender==tokenAddress,"token address is not right");
        require( _value==takeAmt * 10 ** uint256(decimals),"value is not right");
        
        BuyC4YOrder storage buyOrder=buyC4YOrders[_id];
        
        require(buyOrder.orderStatus==OSMaking,"order is cancel");
        require(buyOrder.amtLeft >= takeAmt,"leftamt is not enough");
        require(takeAmt >= buyOrder.amtMin,"takeAmt should >= minamt");
        
        // 注意顺序，必须先转移c4y,因为_transfer里面本身有对调用者账户余额的判断，c4y不足自然会执行失败，
        if(tokenERC20.transferFrom(_from,buyOrder.maker,takeAmt * 10 ** uint256(decimals))){
            
            uint newincome=buyOrder.price*takeAmt*(1000-c4yExchangeFeeRatio)/1000;
            ownerIncome += buyOrder.price*takeAmt - newincome;
            _from.transfer(newincome);
        
            buyOrder.amtLeft -= takeAmt;
        
            emit TakeOrderEvent(buyOrder.maker,_id,takeAmt,buyOrder.price,now,_from);
        }
        
        
        
    }
    
    function getBuyOrderInfoById(uint id)public view returns(uint amtLeft,uint price,uint8 status,uint min){
        
        BuyC4YOrder storage buyOrder=buyC4YOrders[id];
        return (buyOrder.amtLeft,buyOrder.price,buyOrder.orderStatus,buyOrder.amtMin);
    }
    

}