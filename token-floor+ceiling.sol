// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";


// tokenFloorCeiling  
contract tokenFloorCeiling is Ownable {
    // DAO treasury address
    // if address(0), treasury is this contract
    // if other contract, then it's the owner's responsibility to approve to this address
    address treasury;

    // Max/min token supply of governance token
    uint maxTokenSupply;
    uint minTokenSupply = type(uint).max;

    // Denominated in basis points
    uint mintDiscountRate;
    uint burnDiscountRate;

    ERC20 govToken;

    //
    // OWNER-ONLY FUNCTIONS
    //

    constructor(address _treasury, 
                address _govToken, 
                uint _maxTokenSupply, 
                uint _minTokenSupply, 
                uint _mintDiscountRate, 
                uint _burnDiscountRate) {
        setTreasury(_treasury);
        govToken = ERC20(_govToken); // not editable
        setMaxTokenSupply(_maxTokenSupply);
        setMinTokenSupply(_minTokenSupply);
        setMintDiscountRate(_mintDiscountRate);
        setBurnDiscountRate(_burnDiscountRate);
    }

    // Enables owner to change treasyry if needed
    function setTreasury(address _treasury) public ownerOnly {
        if (_treasury != address(0))
            treasury = _treasury;
        else
            treasury = address(this);
    }

    // Can be less than current token supply; will temporarily disable minting
    function setMaxTokenSupply(uint _maxTokenSupply) public ownerOnly {
        maxTokenSupply = _maxTokenSupply;
    }

    // Can be more than current token supply; will temporarily disable burning
    function setMinTokenSupply(uint _minTokenSupply) public ownerOnly {
        minTokenSupply = _minTokenSupply;  
    }

    function setMintDiscountRate(uint _mintDiscountRate) public ownerOnly {
        mintDiscountRate = _mintDiscountRate;
    }

    function setBurnDiscountRate(uint _burnDiscountRate) public ownerOnly {
        burnDiscountRate = _burnDiscountRate;
    }

    // 
    // PUBLIC FUNCTIONS
    // 

    function mint(uint amount) payable public {
        require(govToken.tokenSupply() + amount < maxTokenSupply, "minting too many tokens");
        uint requiredAmount = mintCalculate(amount);
        require(msg.value > requiredAmount);

        if (treasury != address(this))
        {
             (bool sent, ) = treasury.call{value: requiredAmount}("");
            require(sent, "Failed to send Ether");
        }
        _mint(msg.sender, amount);
    }

    function burn(uint amount) public {
        require(govToken.balanceOf(msg.sender) >= amount, "user does not have enough tokens");
        require(govToken.tokenSupply() - amount < minTokenSupply, "burning too many tokens");

        _burn(msg.sender, amount);
        (bool sent, ) = msg.sender.call{value: burnCalculate(amount)}("");
        require(sent, "Failed to send Ether");
    }

    //
    // PRIVATE FUNCTIONS
    //

    // Calculate how much ETH is required to mint amount of tokens
    function mintCalculate(uint amount) private view returns(uint) {
        return ((10000 + mintDiscountRate)
                * ((govToken.tokenSupply() + amount)**2 - govToken.tokenSupply()**2)
                * treasury.balance
                / 2
                / (govToken.tokenSupply()**2));
    }

    // Calculate how much ETH is required to burn amount of tokens
    function burnCalculate(uint amount) private view returns(uint) {
        return ((10000 + mintDiscountRate)
                * (govToken.tokenSupply()**2 - (govToken.tokenSupply() - amount)**2)
                * treasury.balance
                / 2
                / (govToken.tokenSupply()**2));
    }
}