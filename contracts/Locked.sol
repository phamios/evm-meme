// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Violin's locker contract
 * @notice The locker contract allows project admins to lock LP tokens for a period
 * @author Muse
 */ 
contract Locker is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    struct Lock {
        /// @notice The unique identifier of the lock
        uint256 lockId;
        /// @notice The token which was locked
        IERC20 token;
        /// @notice The creator of the lock which might no longer own the lock share
        address creator;
        /// @notice The amount of tokens initially locked
        uint256 amount;
        /// @notice Whether this Lock is still claimable, true from creation until withdrawal.
        bool unclaimed;
        /// @notice The unix timestamp in seconds after which withdrawing the tokens is allowed
        uint256 unlockTimestamp;
        /// @notice The address of the holding contract
        address holdingContract;
        /// @notice Indicates that the Locker governance (operator) can disable the timelock (unlockTimestamp) on this lock.
        /// @notice This could be useful in case the lock owner is scared about deployment issues for example.
        bool unlockableByGovernance;
        /// @notice Indicates whether the Locker governance (operator) has unlocked this lock for early withdrawal by the lock owner.
        /// @notice Can only be set to true by Locker governance (operator) if unlockableByGovernance is set to true.
        bool unlockedByGovernance;
    }

    /// @notice The operator can disable the unlockTimestamp (make a lock withdrawable) if the lock creator permits this.
    address public operator;

    /// @notice An incremental counter that stores the latest lockId (zero means no locks yet).
    Counters.Counter private lockIdCounter;

    /// @notice The list of all locks ever created, the key represents the lockId.
    mapping(uint256 => Lock) private locks;

    /// @notice Changeable name for the share token.
    string private tokenName = "Violin LP Lock";
    /// @notice Changeable symbol for the share token.
    string private tokenSymbol = "LP_LOCK";

    event LockCreated(
        uint256 indexed lockId,
        address indexed token,
        address indexed creator,
        uint256 amount
    );

    event Withdraw(
        uint256 indexed lockId,
        address indexed token,
        address indexed receiver,
        uint256 amount
    );

    event TokenNameChanged(string oldName, string newName);

    event TokenSymbolChanged(string oldSymbol, string newSymbol);

    event GovernanceUnlockChanged(uint256 indexed lockId, bool unlocked);
    event DisableGovernanceUnlockability(uint256 indexed lockId);

    event OperatorTransferred(address oldOperator, address newOperator);

    constructor(address initialOwner) ERC721(tokenName, tokenSymbol) {
        transferOwnership(initialOwner);
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "only operator");
        _;
    }

    /**
     * @notice Creates a new lock by transferring 'amount' to a newly created holding contract.
     * @notice An NFT with the lockId is minted to the user. This NFT is transferrable and represents the ownership of the lock.
     * @param token The token to transfer in
     * @param amount The amount of tokens to transfer in
     * @param unlockTimestamp The timestamp from which withdrawals become possible
     * @param unlockableByGovernance Indicates whether the Locker operator should be able to unlock
     */
    function createLock(
        IERC20 token,
        uint256 amount,
        uint256 unlockTimestamp,
        bool unlockableByGovernance
    ) external nonReentrant {
        require(amount > 0, "zero amount");
        require(unlockTimestamp > block.timestamp, "time passed");
        require(
            unlockTimestamp < 10000000000 ||
                unlockTimestamp == type(uint256).max,
            "too far away"
        );

        lockIdCounter.increment();
        uint256 lockId = lockIdCounter.current();

        address holdingContract = address(new HoldingContract());

        // Before-after pattern is used to figure out the amount actually received, requires reentrancy guard.
        uint256 balanceBefore = token.balanceOf(holdingContract);
        token.safeTransferFrom(msg.sender, holdingContract, amount);
        amount = token.balanceOf(holdingContract) - balanceBefore;

        // It is practically impossible for the lock to already be created, since theoretically counter could eventually overflow we use require in favor of assert.
        require(locks[lockId].creator == address(0), "already exists");

        locks[lockId] = Lock({
            lockId: lockId,
            token: token,
            creator: msg.sender,
            amount: amount,
            unclaimed: true,
            unlockTimestamp: unlockTimestamp,
            holdingContract: holdingContract,
            unlockableByGovernance: unlockableByGovernance,
            unlockedByGovernance: false
        });

        // The ownership share is minted to the creator.
        // It should be noted that anyone can unlock the lock if they own the share.
        _mint(msg.sender, lockId);

        emit LockCreated(lockId, address(token), msg.sender, amount);
    }

    /**
     * @notice Withdraws 'amount' amount of tokens from the locked position. Can only be called by the current owner of the lock NFT.
     * @notice Once the remaining amount reaches zero, the NFT is burned.
     * @notice The ownership share is therefore not fractional as it would complicate things for the user.
     * @param lockId The id of the locked position
     */
    function withdraw(uint256 lockId) external nonReentrant {
        require(isValidLock(lockId), "invalid lock id");

        Lock storage lock = locks[lockId];
        IERC20 token = lock.token;
        address holdingContract = lock.holdingContract;

        require(
            block.timestamp >= lock.unlockTimestamp ||
                lock.unlockedByGovernance,
            "still locked"
        );
        require(lock.unclaimed, "already claimed");
        require(ownerOf(lockId) == msg.sender, "not owner of lock share token");

        // Mark lock as claimed and burn ownership token
        lock.unclaimed = false;
        _burn(lockId);

        uint256 amount = token.balanceOf(holdingContract);
        // Transfer out tokens to sender

        HoldingContract(holdingContract).transferTo(
            token,
            msg.sender,
            amount
        );

        emit Withdraw(lockId, address(lock.token), msg.sender, amount);
    }

    /// @notice if the lock owner wants to reduce their privileges further in case they gave governance unlockability, they can call this function.
    function disableUnlockableByGovernance(uint256 lockId)
        external
        nonReentrant
    {
        require(isValidLock(lockId), "invalid lock id");
        require(ownerOf(lockId) == msg.sender, "not owner of lock share token");
        Lock storage lock = locks[lockId];
        require(lock.unlockableByGovernance, "already not unlockable");

        lock.unlockableByGovernance = false;
        lock.unlockedByGovernance = false;

        emit DisableGovernanceUnlockability(lockId);
    }

    /// @notice All though unnecessary, add reentrancy guard to token transfer in defense.
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override nonReentrant {
        super._transfer(from, to, tokenId);
    }

    //* VIEW FUNCTIONS *//

    /// @notice returns whether the lockId exists (is created)
    function isValidLock(uint256 lockId) public view returns (bool) {
        return lockId != 0 && lockId <= lockIdCounter.current();
    }

    /**
     * @notice Returns information about a specific Lock.
     * @dev The lock data should be indexed using TheGraph or similar to ensure users can always easily find their lockIds.
     * @dev Reverts in case the lockId is out of range.
     * @return The lock related to the lockId.
     */
    function getLock(uint256 lockId) external view returns (Lock memory) {
        require(isValidLock(lockId), "out of range");

        return locks[lockId];
    }

    /**
     * @notice Gets the incremental id of the most recent lock. The first lock is at id 1.
     * @dev A lastLockId of zero means there are no locks yet!
     * @return The id of the latest lock.
     */
    function lastLockId() external view returns (uint256) {
        return lockIdCounter.current();
    }

    //* GOVERNANCE FUNCTIONS *//

    /// @notice The token name and symbol are upgradeable in case of rebranding.
    function setTokenNameAndSymbol(
        string calldata _name,
        string calldata _symbol
    ) external onlyOwner {
        if (!stringsEqual(tokenName, _name)) {
            string memory oldName = tokenName;
            tokenName = _name;
            emit TokenNameChanged(oldName, _name);
        }

        if (!stringsEqual(tokenSymbol, _symbol)) {
            string memory oldSymbol = tokenSymbol;
            tokenSymbol = _symbol;
            emit TokenSymbolChanged(oldSymbol, _symbol);
        }
    }

    /**
     * @notice In case the lock owner allows it, governance can disable the timelock.
     * @dev This can be useful in case the owner makes a mistake during deployment and the actual withdraw can only be done by the consent of both parties.
     * @dev The frontend should clearly indicate when a lock is unlockable and when it is actually unlocked.
     */
    function changeLockStatusByGovernance(uint256 lockId, bool unlocked)
        external
        onlyOperator
        nonReentrant
    {
        require(isValidLock(lockId), "invalid lock");
        Lock storage lock = locks[lockId];
        require(lock.unlockableByGovernance, "not allowed to unlock");
        require(lock.unlockedByGovernance != unlocked, "already set");

        lock.unlockedByGovernance = unlocked;

        emit GovernanceUnlockChanged(lockId, unlocked);
    }

    /// @notice Transfer the operator address to a new address, only callable by owner.
    function transferOperator(address newOperator)
        external
        onlyOwner
        nonReentrant
    {
        require(newOperator != operator, "already set");
        address oldOperator = operator;

        operator = newOperator;

        emit OperatorTransferred(oldOperator, newOperator);
    }

    //* OTHERS *//

    /// @notice Override the token name to allow for rebranding.
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /// @notice Override the token symbol to allow for rebranding.
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function stringsEqual(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

/**
 * @title Violin's HoldingContract to manage individually locked positions.
 * @notice The HoldingContract stores an individually locked position, it can only be unlocked by the main locker address, which should be a Violin locker.
 * @author Muse
 */
contract HoldingContract {
    using SafeERC20 for IERC20;

    /// @notice The locker contract contains the actual information of the lock and is the only address that can unlock funds.
    address public immutable locker;

    constructor() {
        locker = msg.sender;
    }

    /**
     * @notice Allows locker contract to transfer an amount of tokens in the HoldingContract to the recipient
     * @dev All though there is no explicit locking mechanism here, this contract is supposed to be created and managed by the Locker, which has such functionality.
     * @dev For users that are inspecting this contract, we recommend checking the web interface to find out what the locking details are of this lock.
     */
    function transferTo(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external {
        require(msg.sender == locker);
        token.safeTransfer(recipient, amount);
    }
}