module Main where

import Control.Monad
import Graphics.UI.Gtk
import Control.Concurrent
import Control.Concurrent.MVar
import Graphics.Rendering.Cairo
import Graphics.UI.Gtk.Gdk.Events
import Sokoban
import System.Directory (getDirectoryContents, setCurrentDirectory)
import Data.List
import System.FilePath
import Prelude hiding(Either(..))


--TODO: Handle Keyboard input. Draw on window

type Tile = (String, IO Surface)
data Tiles = Tiles {bg :: Surface, pl :: Surface, wall :: Surface, crate :: Surface, target :: Surface}

data State = State {levels :: [Level], curLevelCounter :: Int, curLevel :: Level}

tileWidth = 100
tileHeight = 100



drawTile :: Surface -> Coord -> Render ()
drawTile tile (x,y) =  do
                        setSourceSurface tile (fromIntegral (x*tileWidth)) (fromIntegral (y*tileHeight))
                        paint

                    
drawLevel :: Tiles -> MVar State -> Render ()
drawLevel tiles stateMV = do
                        state <- liftIO $ readMVar stateMV
                        let level = curLevel state                        
                        mapM (drawTile (wall tiles)) (walls level)
                        mapM (drawTile (target tiles)) (targets level)
                        mapM (drawTile (crate tiles)) (crates level)
                        drawTile (pl tiles) (player level)
                        
loadTiles :: IO Tiles
loadTiles = do
        bgImg <- imageSurfaceCreateFromPNG "tiles/freeBackground.png"
        wallImg <- imageSurfaceCreateFromPNG "tiles/wall.png"
        playerImg <- imageSurfaceCreateFromPNG "tiles/player.png"
        crateImg <- imageSurfaceCreateFromPNG "tiles/crate.png"
        targetImg <- imageSurfaceCreateFromPNG "tiles/target.png"

        return Tiles{bg = bgImg, pl = playerImg, wall = wallImg, crate = crateImg, target = targetImg}

parseLevel :: IO State
parseLevel = do
                s <- readFile "level/Level1.lvl"
                lvl <- return $ loadLevel s
                return State {levels = [lvl], curLevelCounter =0, curLevel = lvl}

handleKeyboard :: MVar State -> Window -> Event -> IO ()
handleKeyboard stateMV window key = do
                                    state <- liftIO $ takeMVar stateMV
                                    let lvl = curLevel state
                                    let keyChar = eventKeyChar key
                                    putStrLn ("Handle key " ++ show(keyChar))
                                    case keyChar of
                                        Just 'w' -> performAction state Up 
                                        Just 's' -> performAction state Down
                                        Just 'a' -> performAction state Left
                                        Just 'd' -> performAction state Right
                                        Just 'r' -> performUndo state
                                        Just 'q' -> do
                                                        mainQuit
                                                        return ()
                                        otherwise -> do
                                                    putStrLn ("Unknown key " ++ show(keyChar))
                                                    putMVar stateMV state
                                    
                                    where 
                                        --lvl = curLevel state
                                        performAction state cmd = do
                                                        let updatedLevel = step (curLevel state) cmd
                                                        if isSolved (curLevel state)
                                                            then loadNextLevel state
                                                            else do
                                                                    when (isSolved updatedLevel) $ putStrLn "Level done!"
                                                                    putMVar stateMV $ state{curLevel = updatedLevel}
                                                        widgetQueueDraw window
                                        performUndo state = do
                                                        putMVar stateMV $ state{curLevel = stepBack (curLevel state)}
                                                        widgetQueueDraw window

                                        loadNextLevel state@State {curLevelCounter = counter, levels = lvls}
                                            | counter + 1 < length lvls = putMVar stateMV $ state{curLevel = lvls!!(counter+1), curLevelCounter = counter+1}
                                            | otherwise = do
                                                             putStrLn "You have beaten all level!" 
                                                             mainQuit
                                                             return ()


main :: IO ()
main = do
    initGUI
    window <- windowNew
    --window `on` sizeRequest     $ return (Requisition 800 600)
    onSizeRequest window (return  (Requisition 800 600))
    
    frame <- frameNew
    containerAdd window frame
    --canvas <- drawingAreaNew
    --containerAdd frame canvas
    

    onDestroy window mainQuit
    widgetShowAll window

    drawin <- widgetGetDrawWindow window
    tiles <- loadTiles
    state <- parseLevel
    stateMV <- newMVar state 
    onExpose window (\x -> do renderWithDrawable drawin (drawLevel tiles stateMV) 
                              --putStrLn "drawLevel"  
                              return True)
    onKeyPress window (\x -> do handleKeyboard stateMV window x
                                return True)
    --canvas `on` exposeEvent $ drawLevel drawin tiles state
    
    mainGUI
