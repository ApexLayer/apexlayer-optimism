// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ISemver} from 'src/universal/ISemver.sol';

interface PufferVault {
  function previewRedeem(uint256 shares) external view returns (uint256);
}

interface EEth {
  function liquidityPool() external view returns (address);
}

interface EEthLiquidityPool {
  function amountForShare(uint256 _share) external view returns (uint256);
}

interface EzEthManager {
  function ezEth() external view returns (address);

  function renzoOracle() external view returns (address);

  function calculateTVLs()
    external
    view
    returns (uint256[][] memory, uint256[] memory, uint256);
}

interface EzEth {
  function totalSupply() external view returns (uint);
}

interface RenzoOracle {
  function calculateRedeemAmount(
    uint256 _ezETHBeingBurned,
    uint256 _existingEzETHSupply,
    uint256 _currentValueInProtocol
  ) external pure returns (uint256);
}

abstract contract LSTPriceOracleStorage {
  /**
   * @custom:storage-location erc7201
   * @dev +-----------------------------------------------------------+
   *      |                                                           |
   *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
   *      |                                                           |
   *      +-----------------------------------------------------------+
   */
  enum TokenType {
    None,
    OneToOne,
    EEth,
    EzEth,
    PufferEth
  }

  struct LSTOracleStorage {
    mapping(address => TokenType) tokens;
  }

  // keccak256(abi.encode(uint256(keccak256("lstoracle.storage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant _LST_STORAGE =
    0x24c4f4c7f6f88d574da1c353870b4785def8f1a556239d77ccfd8c83262f8f00;

  function _getStorage() internal pure returns (LSTOracleStorage storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := _LST_STORAGE
    }
  }
}

contract LSTPriceOracle is
  LSTPriceOracleStorage,
  ISemver,
  Initializable,
  OwnableUpgradeable
{
  /// @notice Semantic version.
  /// @custom:semver 0.0.1
  string public constant version = '0.0.1';

  // PufferVault(0xD9A442856C234a39a81a089C06451EBAa4306a72);
  // EEth(0x1B47A665364bC15C28B05f449B53354d0CefF72f);
  // EzEthManager(0x74a09653A083691711cF8215a6ab074BB4e99ef5);

  struct TokenMap {
    address token;
    TokenType tokType;
  }

  constructor() {
    initialize({_owner: address(0xdEaD)});
  }

  function initialize(address _owner) public initializer {
    super.__Ownable_init();
    super._transferOwnership(_owner);
  }

  function getEthValue(
    address token,
    uint shares
  ) external view returns (uint256) {
    LSTOracleStorage storage $ = _getStorage();
    TokenType tokType = $.tokens[token];
    if (tokType == TokenType.PufferEth) {
      return PufferVault(token).previewRedeem(shares);
    } else if (tokType == TokenType.EEth) {
      return
        EEthLiquidityPool(EEth(token).liquidityPool()).amountForShare(shares);
    } else if (tokType == TokenType.EzEth) {
      EzEthManager ezEthManager = EzEthManager(token);

      (, , uint256 totalTVL) = ezEthManager.calculateTVLs();
      return
        RenzoOracle(ezEthManager.renzoOracle()).calculateRedeemAmount(
          shares,
          EzEth(ezEthManager.ezEth()).totalSupply(),
          totalTVL
        );
    } else if (tokType == TokenType.OneToOne) {
      return shares;
    }
    revert('LSTPriceOracle: unknown token');
  }

  function setTokenTypes(TokenMap[] calldata _tokens) external onlyOwner {
    LSTOracleStorage storage $ = _getStorage();
    for (uint256 i = 0; i < _tokens.length; i++) {
      $.tokens[_tokens[i].token] = _tokens[i].tokType;
    }
  }
}
