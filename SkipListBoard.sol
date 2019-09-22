
pragma solidity ^0.4.24;

library SkipListBoard {
    uint256 constant private MAX_LVL = 10;				// Max level of skip list
    uint256 constant private MOD_RND = 100000000000;	// Random modulo

    struct LeftNode {					// Stores the left node info before inserting
        uint256[MAX_LVL+1] score;		// The left node score
        uint256[MAX_LVL+1] next;		// The left node's next node
    }

    struct SkipList {					// Skip list Struct
        uint256 maxLevel;				// Skip list's max level
        uint256 p;						// Skip list's P
        uint256 level;					// Skip list's highest level
        uint256 nodeCount;				// Skip list's node Count
        bool ascending;					// Skip list' score order (ascending or descending)
        mapping (uint256 => uint256) playerMap; // Maps a player to its specific node/score
        mapping (uint256 => uint256[2]) nodeMap; // Maps node/score to its specfic left and right node/score. 
												 // 0 index is next node, 1 index is previous node
												 // Node score, contains the score,player number,level
    }
	
	/**
	**	@dev  initializes the skip list
	**	@param  skip - skip list to initialize
	**	@param  maxLevel - maximum height/level of skip list
	**  @param  p - the P value for the skip list
	**	@param  ascending - indicates whether the list will be sorted ascending or descending
	**/
    function init(SkipList storage skip, uint256 maxLevel, uint256 p, bool ascending) public {
        skip.maxLevel = maxLevel;		// Sets the max level
        skip.p = p;						// Sets the P
        skip.level = 1;					// Highest level initially set to 1
        skip.nodeMap[1][0] = 1;			// Header score == 1, its next points to its own node
        skip.nodeMap[1][1] = 1;			// Header score == 1, its previous points to its own node
        skip.ascending = ascending;		// Indicate the order of skip list
    }

	/**
	**	@dev  generates a random level for the new node to be inserted
	**	@param  maxLevel - maximum height/level of skip list
	**  @param  p - the P value of the skip list
	**	@param  score - user-initiated value
	**	@return  rndLevel - the generated random level
	**/	
    function random(uint256 maxLevel, uint256 p, uint256 score) internal view returns (uint256 rndLevel) {
		rndLevel = 1;
        while ((uint256(
                keccak256(abi.encodePacked(
                    block.timestamp - rndLevel, block.number - rndLevel, 
					(uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now) - rndLevel,
					(uint256(keccak256(abi.encodePacked(msg.sender)))) / (now) - rndLevel,
					block.gaslimit - rndLevel,
					score - rndLevel
				))
				) % MOD_RND < p
			) && (rndLevel < maxLevel)
        )
            rndLevel++;
    }

	/**
	**	@dev  inserts a new node in skip list
	**	@param  skip - the skip list where new values will be inserted
	**  @param  player - the player number (key)
	**	@param  score - the score (value == score + key)
	**	@return  indicates whether new node was inserted (true) or node already in there already (false)
	**/		
    function insert(SkipList storage skip, uint256 player, uint256 score) internal returns (bool) {
        if (skip.playerMap[player] != 0) {
            return false; // Cannot insert what has already been inserted, delete first
        }

		// Node value has a format score + player(9 digits) + level(4 digits)
        LeftNode memory leftNode;
        uint256 rightNode = skip.level;
        score = score*1000000000 + player;
        uint256 i = skip.level;
        uint256 lvlScore;
		
		// Start from the top level to bottom level, look for the left nodes where the node will be inserted
        for (rightNode=skip.level;rightNode % 10000 != 0;rightNode--) {
            lvlScore = score*10000 + i;
            if (skip.ascending)
              while (skip.nodeMap[rightNode][0] != i &&  skip.nodeMap[rightNode][0] < lvlScore)
                  rightNode = skip.nodeMap[rightNode][0];
            else
              while (skip.nodeMap[rightNode][0] != i &&  skip.nodeMap[rightNode][0] > lvlScore)
                  rightNode = skip.nodeMap[rightNode][0];
            leftNode.score[i] = rightNode;
            leftNode.next[i--] = skip.nodeMap[rightNode][0];
        }
        rightNode = skip.nodeMap[++rightNode][0];
        if (rightNode != score || score == 1) {
			// Generate a random level for the new node to be inserted
            uint256 level = random(skip.maxLevel, skip.p, score);
            uint256[2] memory insertNode;

			// Update the top level
            if (level > skip.level) {
                skip.level = level;
            }
			// Start from the bottom level and insert the new node
			// between the left nodes and it's corresponding next nodes
            for (i = 1;i < level+1;i++) {
                lvlScore = score*10000 + i;
                uint256 lnext = leftNode.next[i];
                uint256 lscore = leftNode.score[i];

                if (lscore != 0)
                    skip.nodeMap[lscore][0] = lvlScore;
                else {
                    skip.nodeMap[i][0] = lvlScore;
                    leftNode.score[i] = i;
                }              
                if (lnext != 0)
                    skip.nodeMap[lnext][1] = lvlScore;
                else {
                    skip.nodeMap[i][1] = lvlScore;
                    leftNode.next[i] = i;
                }
                insertNode[0] = leftNode.next[i];                
                insertNode[1] = leftNode.score[i];
                skip.nodeMap[lvlScore] = insertNode;
            }
			// Player map stores the bottom level score, 
			// Account additonal nodes and is equal to the new node's level
            skip.playerMap[player] = score*10000 + 1;
            skip.nodeCount += level;
        }
        return true;
    }

	/**
	**	@dev  removes a node in skip list
	**	@param  skip - the skip list where node will be deleted
	**  @param  player - the player number to be deleted (key)
	**/			
    function remove(SkipList storage skip, uint256 player) internal {
		// Access the node to be removed directly from the player map
        if (skip.playerMap[player] != 0) {
            uint256 lvlScore = skip.playerMap[player];
            uint256[2] memory remNode = skip.nodeMap[lvlScore];
            uint256 remLvl = 1;
			
			// Update the nexts and previouses after the node is gone
			// Remove the node in the map
            while (remNode[0] != 0 || remNode[1] != 0) {
                skip.nodeMap[remNode[0]][1] = remNode[1];
                skip.nodeMap[remNode[1]][0] = remNode[0];
                delete skip.nodeMap[lvlScore];
                remNode = skip.nodeMap[++lvlScore];
                remLvl++;
            }
			// If there's no node in the top levels, remove header nodes and update the level
            while (skip.level > 1 && skip.nodeMap[skip.level][0] == skip.level) {
				delete skip.nodeMap[skip.level];
                skip.level -= 1;
			}
			// Update the node count and delete entry in the player map 
            skip.nodeCount -= (remLvl - 1);
            skip.playerMap[player] = 0;
        }
    }

	/**
	**	@dev  updates a score, delete the old score and insert the new score
	**	@param  skip - the skip list where values will be updated
	**  @param  player - the player number (key)
	**	@param  score - the score (value == score + key)
	**/			
    function update(SkipList storage skip, uint256 player, uint256 score) public {
        remove(skip, player);
        insert(skip, player, score);
    }

	/**
	**	@dev  	gets the top N (i.e. first entry up to N entries above) entries in the skip list
	**	@param  skip - the skip list to be searched
	**  @param  n - the number of entries to retrieve
	**  @return  the list of entries from first up to Nth entries
	**/				
    function getTopN(SkipList storage skip, uint256 n) public view returns (uint256[]){
        uint256[] memory scores = new uint256[](n);
        uint256 nodeScore = skip.nodeMap[1][0];
		if (nodeScore == 0) return scores;
        uint256 i = 0;

        while (nodeScore != 1 && i < n) {
            scores[i] = nodeScore;
            nodeScore = skip.nodeMap[nodeScore][0];
            i++;
        }
        return scores;
    }

	/**
	**	@dev  	gets the last N (i.e. last entry up to N entries below) entries in the skip list
	**	@param  skip - the skip list to be searched
	**  @param  n - the number of entries to retrieve
	**  @return  the list of entries from last up to Nth entries
	**/				
    function getBottomN(SkipList storage skip, uint256 n) public view returns (uint256[]){
        uint256[] memory scores = new uint256[](n);
        uint256 nodeScore = skip.nodeMap[1][1];
		if (nodeScore == 0) return scores;		
        uint256 i = 0;

        while (nodeScore != 1 && i < n) {
            scores[i] = nodeScore;
            nodeScore = skip.nodeMap[nodeScore][1];
            i++;
        }
        return scores;
    }

	/**
	**	@dev  	gets N nodes/entries from the right of a player's node
	**	@param  skip - the skip list to be searched
	**	@param  player - the start node where entries will be retrieved
	**  @param  n - the number of entries to retrieve
	**  @return  the list of N entries from the right of a player's node
	**/					
    function getRightN (SkipList storage skip, uint256 player, uint256 n) public view returns (uint256[]) {
        uint256[] memory scores = new uint256[](n);
        uint256 nodeScore = skip.nodeMap[skip.playerMap[player]][0];
		if (nodeScore == 0) return scores;		
        uint256 i = 0;

        while (nodeScore != 1 && i < n) {
            scores[i] = nodeScore;
            nodeScore = skip.nodeMap[nodeScore][0];
            i++;
        }
        return scores;
    }
	
	/**
	**	@dev  	gets N nodes/entries from the left of a player's node
	**	@param  skip - the skip list to be searched
	**	@param  player - the start node where entries will be retrieved
	**  @param  n - the number of entries to retrieve
	**  @return  the list of N entries from the left of a player's node
	**/					
    function getLeftN (SkipList storage skip, uint256 player, uint256 n) public view returns (uint256[]) {
        uint256[] memory scores = new uint256[](n);
        uint256 nodeScore = skip.nodeMap[skip.playerMap[player]][1];
		if (nodeScore == 0) return scores;		
        uint256 i = 0;

        while (nodeScore != 1 && i < n) {
            scores[i] = nodeScore;
            nodeScore = skip.nodeMap[nodeScore][1];
            i++;
        }
        return scores;
    }

	/**
	**	@dev  	gets list nodes/entries of the skip list data structure
	**	@param  skip - the skip list to be searched
	**  @return  the list of all nodes/entries of the skip list data structure
	**/						
    function getList (SkipList storage skip) public view returns (uint256[]) {
        uint256[] memory scores = new uint256[](skip.nodeCount+skip.level);
        uint256 j = 0;

        for (uint256 i = 1; i < skip.level + 1;i++) {
            scores[j++] = i;
            uint256 nodeScore = skip.nodeMap[i][0];
            while (nodeScore != i) {
                scores[j++] = nodeScore;
                nodeScore = skip.nodeMap[nodeScore][0];
            }
        }
        return scores;
    }

	/**
	**	@dev  	gets the bottom entry of the skip list
	**	@param  skip - the skip list to be searched
	**	@return  the bottom entry (score)
	**/						
    function getBottom(SkipList storage skip) public view returns (uint256){
        return skip.nodeMap[1][1];
    }
}

