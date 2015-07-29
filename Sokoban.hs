module Sokoban where

import Prelude hiding (Either(..))
import Data.List (delete, sort)

type Coord = (Int, Int)

type MovedWithCrate = Bool

data Command = Up | Down | Left | Right deriving (Show)

inv :: Command -> Command
inv Up = Down
inv Down = Up
inv Left = Right
inv Right = Left

data Level = Level {walls :: [Coord], 
                    crates :: [Coord], 
                    targets :: [Coord], 
                    player :: Coord, 
                    moves :: [(Command, MovedWithCrate)], 
                    steps :: Int } deriving (Show)

--Consumes elements of the form (coord, char) and fills the list of walls, crates, targets as well as the player position according to the characters in the elements
consumeElems :: [(Coord, Char)] -> [Coord] -> [Coord] -> [Coord] -> Coord -> ([Coord], [Coord], [Coord], Coord)
consumeElems [] ws cs ts pl = (ws, cs, ts, pl)
consumeElems ((cord,char):els) ws cs ts pl = case char of
                                            '@' -> consumeElems els ws cs ts cord
                                            '#' -> consumeElems els (cord:ws) cs ts pl
                                            '.' -> consumeElems els ws cs (cord:ts) pl
                                            '$' -> consumeElems els ws (cord:cs) ts pl
                                            '*' -> consumeElems els ws (cord:cs) (cord:ts) pl
                                            '+' -> consumeElems els ws cs (cord:ts) cord
                                            otherwise -> error (show char ++ " not recognized")


--Parsing function. Extracts characters from string and binds them to x,y coordinates. 
loadLevel :: String -> Level
loadLevel s = Level {walls = ws, crates = cs, targets = ts, player = pl, moves = [], steps = 0}
                where
                    elems = concat $ zipWith zip ([[(x,y) | x<-[0..]] | y<-[0..]]) (lines s)
                    (ws, cs, ts, pl) = consumeElems elems [] [] [] (0,0)


--Applies a command to a coordinate
updateCoord :: Coord -> Command -> Coord
updateCoord (x,y) c = case c of
                            Up -> (x, y+1)
                            Down -> (x, y-1)
                            Left -> (x-1,y)
                            Right -> (x+1, y)

step :: Level -> Command -> Level
step l c = case testLevel of
            Nothing -> l
            Just lvl -> lvl
           where testLevel = updateLevel l c

updateLevel :: Level -> Command -> Maybe Level
updateLevel l c 
    | elem newPos (walls l) = Nothing --Hit a wall -> No valid level
    | elem newPos (crates l) = if elem newCratePos (walls l) || elem newCratePos (crates l) 
                                    then Nothing --Crate would hit wall or other crate -> No valid level
                                    else Just l{player = newPos, steps = (steps l) +1, 
                                                crates=newCratePos:(delete newPos (crates l)), 
                                                moves= (c, True):(moves l)} --Return level with updated player and crate position, by removing old crate position and adding new one
    | otherwise = Just l{player = newPos, moves = (c,False):(moves l), steps = (steps l) + 1} --create new level by updating player position, adding the move and increase step count
        where   newPos = updateCoord (player l) c
                newCratePos = updateCoord newPos c
              
stepBack :: Level -> Level
stepBack l
    | null (moves l) = l
    | otherwise = l {player = newPos, moves = tail (moves l), crates = newCrates}
                    where
                        (cmd, crateMoved) = head (moves l)
                        oldPos = player l
                        newPos = updateCoord oldPos (inv cmd)
                        oldCratePos = updateCoord oldPos cmd
                        newCrates = case crateMoved of
                                        True -> oldPos:(delete oldCratePos (crates l))
                                        False -> crates l

isSolved :: Level -> Bool
isSolved l = sort (crates l) == sort (targets l)
