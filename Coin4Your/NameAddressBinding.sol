pragma solidity ^0.4.25;
import "./Owner.sol";

interface ICoin4You{

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
}

contract NameAddressBinding is Owner{
    

    address c4yCoinAddress=0x692a70d2e424a56d2c6c27aa97d1a86395877b3a;
    ICoin4You c4yContract=ICoin4You(c4yCoinAddress);
    
    uint8 public decimals = 18;
    
    //name address part
    mapping(address => string) addressNameMap;
    mapping(string => address) nameAddressMap;
    mapping(address => string) myHeaderIconMap;
    
    event RegisteNameEvent(address indexed register,string name,uint time);
    
    uint8 public nameMinLength=5;
    uint8 public nameMaxLength=12;
    uint8 public freeNameLength=6;
    uint public registeBasePriceEth=0.01 ether;
    uint public registeBasePriceC4y=1000;
    
    event ChangeMyNameAddressEvent(string name,address newAddrs,address indexed oldAdds);
    
    struct SellInfo{
        
        address seller;
        uint priceByEth;
        uint priceByC4y;
        bool isSelling;
    }
    
    mapping(string =>SellInfo) sellmap;
    
    event SellName(string name,uint priceByEth,uint priceByC4y,address indexed seller);
    
    event CancelSell(string name);
    
    event ChangePrice(string name,uint priceByEth,uint priceByC4y);
    
    event BuyName(string name,address indexed buyer,address indexed olderOwner);
    
    uint public nameSellMaxETH=100 ether;//sell name eth最大支付限额
    uint public nameSellMaxC4Y=10000000;//sell name c4y最大支付限额
    
    uint8 public nameSellFeeRatio=1;
    
    event SetIcon(address indexed setter,string icon);
  
    function utfStringLength(bytes string_rep) private pure
    returns (uint length)
    {
        uint i=0;

        while (i<string_rep.length)
        {
            if (string_rep[i]>>7==0)
                i+=1;
            else if (string_rep[i]>>5==0x6)
                i+=2;
            else if (string_rep[i]>>4==0xE)
                i+=3;
            else if (string_rep[i]>>3==0x1E)
                i+=4;
            else
                //For safety
                i+=1;

            length++;
        }
    } 
    
    function _toLowercase(string str) private pure returns(string){
        bytes memory bStr=bytes(str);
        bytes memory bLower=new bytes(bStr.length);
        for(uint i=0;i<bStr.length;i++){
            
            if((bStr[i] >= 65) && (bStr[i] <= 90)){
                bLower[i]=bytes1(uint8(bStr[i])+32);
            }else{
                bLower[i]=bStr[i];
            }
        }
        
        return string(bLower);
    }
    
    function setNameLength(uint8 min,uint8 max,uint8 freeLength)public onlyOwner {
        
        nameMinLength=min;
        nameMaxLength=max;
        freeNameLength=freeLength;
    }
    
    function setNamePrice(uint regBasePriceEth,uint regBasePriceC4y)public onlyOwner{
        registeBasePriceEth=regBasePriceEth;
        registeBasePriceC4y=regBasePriceC4y;
    }
    
    function registeNameByEth(string name)public payable{
        name=_toLowercase(name);
        uint length=utfStringLength(bytes(name));
        require(length <= nameMaxLength && length >= nameMinLength,"name is too long or too short");
        require(nameAddressMap[name]==0x0,"this name is already registered");
        
        if(length < freeNameLength){
            
            uint needPayValue=registeBasePriceEth * (10 ** (freeNameLength-1-length));
            require(msg.value==needPayValue,"you need send the right value");
            ownerIncome += msg.value;
            
        }
        //解除旧绑定
        nameAddressMap[addressNameMap[msg.sender]]=0x0;
        
        //建立新绑定
        nameAddressMap[name]=msg.sender;
        addressNameMap[msg.sender]=name;
        
        emit RegisteNameEvent(msg.sender,name,now);
        
    }
    
    function getAddress(string name)public view returns(address adds){
        return nameAddressMap[name];
    }
    
    function getName(address adds)public view returns(string name){
        return addressNameMap[adds];
    }
    
    function changeMyNameAddress(string name,address newAddrs)public {
        
        require(newAddrs!=0x0,"new address must not be 0x0");
        require(nameAddressMap[name]==msg.sender,"you are not the name owner");
        //解除旧绑定
        addressNameMap[msg.sender]="";
        nameAddressMap[addressNameMap[newAddrs]]=0x0;
        
        //建立新绑定
        nameAddressMap[name]=newAddrs;
        addressNameMap[newAddrs]=name;
        
        emit ChangeMyNameAddressEvent(name,newAddrs,msg.sender);
    }
    
    function setSellNameMaxPrice(uint maxEth,uint maxC4y)public onlyOwner{
        
        nameSellMaxETH=maxEth;
        nameSellMaxC4Y=maxC4y;
    }
    
    //name exchange
    function sellName(string name,uint priceEth,uint priceC4y)public {
        name=_toLowercase(name);
        require(nameAddressMap[name]==msg.sender,"you are not the name owner");
        
        require(priceEth > 0 || priceC4y > 0,"price must bigger than zero");
        
        if(priceEth > 0){
            require(priceEth <= nameSellMaxETH,"payAmount is exceed nameSellMaxETH");
        }
        
        if(priceC4y > 0){
            require(priceC4y <= nameSellMaxC4Y,"payAmount is exceed nameSellMaxC4Y");
        }
        
        sellmap[name].seller=msg.sender;
        sellmap[name].priceByEth=priceEth;
        sellmap[name].priceByC4y=priceC4y;
        sellmap[name].isSelling=true;
        
        emit SellName(name,priceEth,priceC4y,msg.sender);
        
    }
    
    function cancelSelling(string name)public {
        name=_toLowercase(name);
        require(nameAddressMap[name]==msg.sender,"you are not the name owner");
        sellmap[name].isSelling=false;
        
        emit CancelSell(name);
        
    }
    
    function changeSellPrice(string name,uint newPriceEth,uint newPriceC4y)public{
        name=_toLowercase(name);
        require(nameAddressMap[name]==msg.sender,"you are not the name owner");
        sellmap[name].priceByEth=newPriceEth;
        sellmap[name].priceByC4y=newPriceC4y;
        
        emit ChangePrice(name,newPriceEth,newPriceC4y);
    }
    
    function setNameSellFeeRatio(uint8 ratio)public onlyOwner{
        nameSellFeeRatio=ratio;
    }
    
    function buyNameUseEth(string name)public payable{
        name=_toLowercase(name);
        require(sellmap[name].isSelling==true,"the name is not selling");
        
        //use eth to pay
        require(sellmap[name].priceByEth > 0,"priceEth must big than zero");
        require(msg.value==sellmap[name].priceByEth,"you should send the right value");
        uint sellerIncome=sellmap[name].priceByEth * (100-nameSellFeeRatio)/100;
        ownerIncome += msg.value - sellerIncome; 
        sellmap[name].seller.transfer(sellerIncome);
        
        //解除旧绑定
        addressNameMap[sellmap[name].seller]="";
        nameAddressMap[addressNameMap[msg.sender]]=0x0;
        
        //建立新绑定
        nameAddressMap[name]=msg.sender;
        addressNameMap[msg.sender]=name;
      
        sellmap[name].isSelling=false;

        emit BuyName(name,msg.sender,sellmap[name].seller);
        
        
    }
    
    function setMyicon(string icon)public{
        myHeaderIconMap[msg.sender]=icon;
        emit SetIcon(msg.sender,icon);
    }
    
    function getAddressicon(address addrs)public view returns(string icon){
        
        icon=myHeaderIconMap[addrs];
    }
    
    function toRegisteName(address _from, uint256 _value, address _token, string  name) external{
        
        require(_token==c4yCoinAddress && msg.sender==c4yCoinAddress,"it is not c4y coin");
        string memory _name=_toLowercase(name);
        uint length=utfStringLength(bytes(_name));
            require(length <= nameMaxLength && length >= nameMinLength,"name is too long or too short");
            require(nameAddressMap[_name]==0x0,"this name is already registered");
        
            if(length < freeNameLength){
            
                uint needPayValue=registeBasePriceC4y * (10 ** (freeNameLength-1-length)) * 10 ** uint256(decimals);
                require(_value==needPayValue,"send value is not equal needPayValue");
                
                c4yContract.transferFrom(_from,owner,needPayValue);
            
            }
            //解除旧绑定
            nameAddressMap[addressNameMap[_from]]=0x0;
            
            //建立新绑定
            nameAddressMap[_name]=_from;
            addressNameMap[_from]=_name;
            
            emit RegisteNameEvent(_from,_name,now);
    }
    
    function toBuyName(address _from, uint256 _value, address _token, string name) external{
        
        require(_token==c4yCoinAddress && msg.sender==c4yCoinAddress,"it is not c4y coin");
        string memory _name=_toLowercase(name);
        require(sellmap[_name].isSelling==true,"the name is not selling");
                
            //use c4y to pay
            uint namePriceByC4y=sellmap[_name].priceByC4y * 10 ** uint256(decimals);
            require(namePriceByC4y > 0 && _value==namePriceByC4y,"send value is not equal namePriceByC4y");
            
            c4yContract.transferFrom(_from,sellmap[_name].seller,namePriceByC4y);
            
            //解除旧绑定
            addressNameMap[sellmap[_name].seller]="";
            nameAddressMap[addressNameMap[_from]]=0x0;
            
            //建立新绑定
            nameAddressMap[_name]=_from;
            addressNameMap[_from]=_name;
          
            sellmap[_name].isSelling=false;
    
            emit BuyName(_name,_from,sellmap[_name].seller);
    } 
}