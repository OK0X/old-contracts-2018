pragma solidity ^0.4.25;
import "./Owner.sol";

//C4Y:只是在涉及到transfer的时候需要转换成最小单位，其他情况下都是以个来记的，前端输入也是
//ETH:整个用的都是最小单位wei，所以前端输入的时候要带上18个0，web3js里面以ether记的要转换成wei

interface ICoin4You{

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    
}

contract Coin4Your is Owner {
    
    uint8 public decimals = 18;
    address c4yCoinAddress=0x692a70d2e424a56d2c6c27aa97d1a86395877b3a;//
    ICoin4You c4yContract=ICoin4You(c4yCoinAddress);
    
    uint8 constant Cprivate=0;
    uint8 constant Cpublic=1;
    uint8 constant Cpassword=2;
    uint8 constant Cpay=3;
    
    uint8 constant PublishPayEth=0;
    uint8 constant PublishPayC4Y=1;
    
    uint8 constant PayByEth=0;
    uint8 constant PayByC4Y=1;
    
    uint8 constant InitialReview=0;
    uint8 constant InitialStar=0;
    
    bool public isRewardCoin=true;
    uint public rewardNumberPerPub=1000;
    uint public rewardNumberPerStar=10;
    uint public rewardNumberPerComment=10;
    
    struct Artical{
        uint8 openness;//0:私密，1：公开免费，2：密码,3:公开付费
        uint payAmtEth;
        uint payAmtC4Y;
        uint time;
        uint scoreTimes;//评分次数
        uint scoreSum;//评分
        address publisher;
        string title;
        string tag;
        string summary;
        string pswd;
        string text;
    }
    
    
    Artical[] articals;
    
    event PublishArticalEvent(uint ArticalId,uint8 openness,uint payAmtEth,uint payAmtC4Y,uint time,address indexed publisher,string title,string tag,string summary);
    
    event ModifyArticalEvent(address indexed publisher,uint id,uint openness,uint payAmtETH,uint payAmtC4Y);
    
    event ArticalPayEvent(address indexed author,uint id,string title,string payType,uint amount,address indexed reader);
    
    event ArticleCommentEvent(address indexed author,uint id,string title,string comment,address indexed reader,uint time);
    
    event AddFavoriteEvent(address indexed reader,uint articleId,string title,string summary);
    
    event SubmitScoreEvent(address indexed reader,uint articleId,string title,uint8 score,address indexed author);
    
    uint public publishPriceEth=0.01 ether;
    uint public publishPriceC4Y=2000;
    
    mapping(address => bool) public freePublishAddrs;
    
    uint articalPayMaxETH=100 ether;//eth最大支付限额
    uint articalPayMaxC4Y=10000000;//c4y最大支付限额
    
    uint8 public incomeFeeRatio=1;//作者收入手续费，按100比来
    
    mapping(address => uint[]) myPayedArticles;
    mapping(address => uint[]) myfavoriteArticles;
    
    struct ArticlePSF{
        bool isPayed;
        bool isScore;
        bool isAddFavorite;
    }
    
    mapping(uint => mapping(address => ArticlePSF)) articlePSFMap;
    
    
    function setPublishPrice(uint _priceeth,uint _pricec4y) public onlyOwner{
        
        publishPriceEth=_priceeth;
        publishPriceC4Y=_pricec4y;
    }
    
    function setFreePublishList(address _address,bool _isFree) public onlyOwner{
        
        freePublishAddrs[_address]=_isFree;
    }
    
    function setAuthorIncomeFee(uint8 _feeratio)public onlyOwner{
        incomeFeeRatio=_feeratio;
    }
    
    function setReward(bool _isRewardCoin,uint _rewardNumberPerPub,uint _rewardNumberPerStar,uint _rewardNumberPerComment) public onlyOwner {
        
        isRewardCoin=_isRewardCoin;
        rewardNumberPerPub=_rewardNumberPerPub;
        rewardNumberPerStar=_rewardNumberPerStar;
        rewardNumberPerComment=_rewardNumberPerComment;
    }
    
    function setArticalPayMax(uint _articalPayMax,uint _articalPayMaxC4Y) public onlyOwner{
        
        articalPayMaxETH=_articalPayMax;
        articalPayMaxC4Y=_articalPayMaxC4Y;
    }
    
    function checkPublishPay(uint8 pubPayType)private {
        
        if(!freePublishAddrs[msg.sender]){
            
            // if(PublishPayC4Y==pubPayType){
            //     c4yContract.transfer(owner,publishPriceC4Y * 10 ** uint256(decimals));
            // }else{
            //     require(msg.value==publishPriceEth,"you need to set right value");
            //     ownerIncome += msg.value;
            // }
            
            require(msg.value==publishPriceEth,"you need to set right value");
            ownerIncome += msg.value;
            
        }
    }
    
    function checkPublishReward()private {
        if(isRewardCoin){
            c4yContract.transferFrom(owner,msg.sender,rewardNumberPerPub * 10 ** uint256(decimals));
        }
    }
    
    function checkPayAmt(uint _payAmtETH,uint _payAmtC4Y)private view {
        require(_payAmtETH > 0 || _payAmtC4Y > 0,"pay artical should set one pay amt at least");
        
        if(_payAmtETH > 0){
            require(_payAmtETH <= articalPayMaxETH,"payAmount is exceed articalPayMaxETH");
        }
        
        if(_payAmtC4Y > 0){
            require(_payAmtC4Y <= articalPayMaxC4Y,"payAmount is exceed articalPayMaxC4Y");
        }
    }
    
    function publishArticalNeedPay(uint _payAmtETH,uint _payAmtC4Y,string title,string tag,string summary,string text,uint8 pubPayType) public payable{
        
        checkPublishPay(pubPayType);
        
        checkPayAmt(_payAmtETH,_payAmtC4Y);
        
        uint id=articals.push(Artical(Cpay,_payAmtETH,_payAmtC4Y,now,InitialReview,InitialStar,msg.sender,title,tag,summary,"0",text));
        emit PublishArticalEvent(id,Cpay,_payAmtETH,_payAmtC4Y,now,msg.sender,title,tag,summary);
        
        checkPublishReward();
        
    }
    
    function publishArticalNoPay(string title,string tag,string summary,string text,uint8 pubPayType) public payable{
        
        checkPublishPay(pubPayType);
        
        uint id=articals.push(Artical(Cpublic,0,0,now,InitialReview,InitialStar,msg.sender,title,tag,summary,"0",text));
        emit PublishArticalEvent(id,Cpublic,0,0,now,msg.sender,title,tag,summary);
        
        checkPublishReward();
    }
    
    function publishArticalPswd(string pswd,string title,string tag,string summary,string text,uint8 pubPayType)public payable{
        checkPublishPay(pubPayType);
        
        uint id=articals.push(Artical(Cpassword,0,0,now,InitialReview,InitialStar,msg.sender,title,tag,summary,pswd,text));
        emit PublishArticalEvent(id,Cpassword,0,0,now,msg.sender,title,tag,summary);
        
        checkPublishReward();
        
    }
    
    function publishArticalPrivate(string title,string tag,string summary,string text,uint8 pubPayType)public payable{
        checkPublishPay(pubPayType);
        
        uint id=articals.push(Artical(Cprivate,0,0,now,InitialReview,InitialStar,msg.sender,title,tag,summary,"0",text));
        emit PublishArticalEvent(id,Cprivate,0,0,now,msg.sender,title,tag,summary);
        
    }
    
    function toGetPaidContent(address _from, uint256 _value, address _token, uint _id) external{
        
        require(msg.sender==c4yCoinAddress && _token==c4yCoinAddress,"_token address is not right");
        
        Artical storage artical=articals[_id];
        require(artical.openness==Cpay,"this only called by pay articals");
        require(!articlePSFMap[_id][_from].isPayed,"you are aleady payed");
        
        require(artical.payAmtC4Y>0,"payAmtC4Y must big than zero"); 
        require(_value==artical.payAmtC4Y * 10 ** uint256(decimals),"value is not right");
        c4yContract.transferFrom(_from,artical.publisher,_value);
        emit ArticalPayEvent(artical.publisher,_id,artical.title,"c4y",artical.payAmtC4Y,_from);
        
        articlePSFMap[_id][_from].isPayed=true;
        myPayedArticles[_from].push(_id);
    }
    
    
    function getContext4PayByEth(uint _id)public payable {
        
        Artical storage artical=articals[_id];
        require(artical.openness==Cpay,"this only called by pay articals");
        require(!articlePSFMap[_id][msg.sender].isPayed,"you are aleady payed");
        
        require(artical.payAmtEth>0,"payAmtEth must big than zero");    
        require(msg.value==artical.payAmtEth,"you need to send right eth");
        uint income=artical.payAmtEth*(1000-incomeFeeRatio)/1000;
        ownerIncome += msg.value-income;
        artical.publisher.transfer(income);
            
        emit ArticalPayEvent(artical.publisher,_id,artical.title,"eth",income,msg.sender);
        
        
        articlePSFMap[_id][msg.sender].isPayed=true;
        myPayedArticles[msg.sender].push(_id);
        
        
    }
    
    function getContextAlreadyPay(uint _id)public view returns(string _text){
        
        Artical storage artical=articals[_id];
        require(articlePSFMap[_id][msg.sender].isPayed,"you should pay first");
        return artical.text;
        
    }
    
    function getContextNoPay(uint _id,string _pswd)public view returns(string _text){
        
        Artical storage artical=articals[_id];
        uint8 _openness=artical.openness;
        if(Cprivate==_openness){
            //私密
            if(msg.sender==artical.publisher){
                
                return artical.text;
            }else{
                
                return "this artical is private, only author can read it";
            }
        }else if(Cpublic==_openness){
            //公开
            return artical.text;
        }else if(Cpassword==_openness){
            //密码
            require(keccak256(abi.encodePacked(_pswd))==keccak256(abi.encodePacked(artical.pswd)),"password is not right");
            return artical.text;
        }else{
            return "it is a pay artical,you should pay first";
        }
    }
    
    function getMyArtical(uint _id)public view returns(string _pswd,string _text){
        Artical storage artical=articals[_id];
        require(artical.publisher==msg.sender,"you are not the artical author");
        return (artical.pswd,artical.text);
    }
    
    function modifyArticalOpenness(uint id,uint8 _openness,uint _payAmtETH,uint _payAmtC4Y,string password) public {
        
        Artical storage artical=articals[id];
        require(msg.sender==artical.publisher,"only author can modify");
        artical.openness=_openness;
        if(Cpay==_openness){
            checkPayAmt(_payAmtETH,_payAmtC4Y);
        }
        artical.payAmtEth=_payAmtETH;
        artical.payAmtC4Y=_payAmtC4Y;
        artical.pswd=password;
        emit ModifyArticalEvent(artical.publisher,id,_openness,_payAmtETH,_payAmtC4Y);
    }
    
    function getNewOpennessById(uint _id)public view returns(uint8 _openness,uint _payAmtETH,uint _payAmtC4Y){
        Artical storage artical=articals[_id];
        return (artical.openness,artical.payAmtEth,artical.payAmtC4Y);
    }
    
    function submitScore(uint id,uint8 _score) public {
        
        require(_score >= 1 && _score <= 5,"score num shoud between 1 to 5");
        require(articlePSFMap[id][msg.sender].isScore==false,"you alread star it");
        Artical storage artical=articals[id];
        artical.scoreSum=artical.scoreSum+_score;
        artical.scoreTimes++;
        articlePSFMap[id][msg.sender].isScore=true;
        
        if(isRewardCoin){
            c4yContract.transferFrom(owner,msg.sender,rewardNumberPerStar * 10 ** uint256(decimals));
        }
        
        emit SubmitScoreEvent(msg.sender,id,artical.title,_score,artical.publisher);
        
    }
    
    function addFavorite(uint _id)public {
        Artical storage artical=articals[_id];
        require(articlePSFMap[_id][msg.sender].isAddFavorite==false,"you have aleady addFavorite");
        myfavoriteArticles[msg.sender].push(_id);
        articlePSFMap[_id][msg.sender].isAddFavorite=true;
        emit AddFavoriteEvent(msg.sender,_id,artical.title,artical.summary);
    }
    
    function getMyPayedArticles()public view returns(uint[] payedArticles){
        
        return myPayedArticles[msg.sender];
    }
    
    function getMyFavoriteArticles()public view returns(uint[] favoriteArticles){
        
        return myfavoriteArticles[msg.sender];
    }
    
    function ownerWithdraw(uint amount) public onlyOwner {
        
        msg.sender.transfer(amount);
    }
    
    function getReviewStarbyId(uint _id)public view returns(uint _review,uint _star){
        
        Artical storage artical=articals[_id];
        return (artical.scoreTimes,artical.scoreSum);
    }
    
    function submitComment(uint _id,string _comment)public {
        Artical storage artical=articals[_id];
        if(artical.openness==Cpay){
            
            require(articlePSFMap[_id][msg.sender].isPayed==true,"you should read it first");
        }
        
        if(isRewardCoin){
            c4yContract.transferFrom(owner,msg.sender,rewardNumberPerComment * 10 ** uint256(decimals));
        }
        
        emit ArticleCommentEvent(artical.publisher,_id,artical.title,_comment,msg.sender,now);
    }
    
    function getArticlePSF(uint id)public view returns(bool isPayed,bool isScore,bool isAddFavorite){
        
        isPayed=articlePSFMap[id][msg.sender].isPayed;
        isScore=articlePSFMap[id][msg.sender].isScore;
        isAddFavorite=articlePSFMap[id][msg.sender].isAddFavorite;
    }
    
    
    
    
}