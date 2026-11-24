module Main (main) where

import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Data.Char (isDigit)
import Data.Maybe (mapMaybe)
import Data.Word (Word64)
import Foreign.C.Types (CFloat, CUInt)
import Options.Applicative
import Options.Applicative.Common (evalParser)
import SDL3 hiding (cos, info, round, sin)
import Text.Read (readMaybe)

data Action = Quit

data World = World {quitting :: Bool}
defaultWorld :: World
defaultWorld = World{quitting = False}

uv0 :: SDLFPoint
uv0 = SDLFPoint 0 0

triangleVertices :: [SDLVertex]
triangleVertices =
  [ SDLVertex (SDLFPoint 100 100) triangleColor uv0
  , SDLVertex (SDLFPoint 100 200) triangleColor uv0
  , SDLVertex (SDLFPoint 300 100) triangleColor uv0
  ]
  where
    triangleColor = SDLFColor 1 1 1 1

circleVertices :: CFloat -> CFloat -> CFloat -> [SDLVertex]
circleVertices x y r = concatMap (\(p1, p2) -> [p1, p2, center]) rim
  where
    steps :: Int
    steps = 32
    angleStep :: CFloat
    angleStep = pi * 2 / fromIntegral steps
    circleColor = SDLFColor 0 0 1 1
    center = SDLVertex (SDLFPoint x y) circleColor uv0
    pointN :: Int -> SDLFPoint
    pointN n = SDLFPoint (x + r * cos (fromIntegral n * angleStep)) (y + r * sin (fromIntegral n * angleStep))
    vertexN :: Int -> SDLVertex
    vertexN n = SDLVertex (pointN n) circleColor uv0
    rim :: [(SDLVertex, SDLVertex)]
    rim = let xs = [vertexN v | v <- [0 .. steps]] in zip xs (tail xs)

windowTitle :: String
windowTitle = "interactive-window"
windowWidth :: Int
windowWidth = 800
windowHeight :: Int
windowHeight = 600
windowFlags :: CUInt
windowFlags = 0

nsPerSecond :: Double
nsPerSecond = 1e9

nsToSeconds :: Word64 -> Double
nsToSeconds ns = fromIntegral ns / nsPerSecond

secondsToNs :: Double -> Word64
secondsToNs s = round (s * nsPerSecond)

sdlFail :: String -> IO a
sdlFail what = (\e -> fail (what <> ": " <> e)) =<< sdlGetError

createSDLWindowAndRenderer :: IO (SDLWindow, SDLRenderer)
createSDLWindowAndRenderer =
  maybe (sdlFail "SDL_CreateWindowAndRenderer") pure
    =<< sdlCreateWindowAndRenderer windowTitle windowWidth windowHeight windowFlags

withSDLWindowAndRenderer :: ((SDLWindow, SDLRenderer) -> IO a) -> IO a
withSDLWindowAndRenderer =
  bracket
    createSDLWindowAndRenderer
    (\(window, renderer) -> sdlDestroyRenderer renderer >> sdlDestroyWindow window)

vertexToTuple :: SDLVertex -> (CFloat, CFloat)
vertexToTuple (SDLVertex (SDLFPoint x y) _ _) = (x, y)

main :: IO ()
main = do
  sdlInit [SDL_INIT_VIDEO] `orFail` "SDL_Init"
  withSDLWindowAndRenderer (\(_, renderer) -> run renderer) `finally` sdlQuit
  where
    orFail act what = act >>= \ok -> unless ok (sdlFail what)
    run renderer = do
      _ <- sdlSetRenderVSync renderer 1 -- 1: sync to every display refresh
      startTick <- sdlGetTicksNS
      loop renderer defaultWorld startTick
    loop renderer world ticksNS = do
      ticksNS' <- sdlGetTicksNS
      let dt = nsToSeconds $ ticksNS' - ticksNS
      world' <- step dt . foldl' apply world <$> drainActions
      unless (quitting world') $ do
        _ <- sdlSetRenderDrawColor renderer 0 0 0 255 -- black background
        _ <- sdlRenderClear renderer
        _ <- sdlSetRenderDrawColor renderer 0 255 0 255
        _ <- sdlRenderFillRect renderer (Just $ SDLFRect 100 100 100 100)
        _ <- sdlRenderGeometry renderer Nothing (circleVertices 400 300 50) Nothing
        _ <- sdlRenderPresent renderer
        loop renderer world' ticksNS'

{- basic implementation
drainEvents :: IO [SDLEvent]
drainEvents = do
  mev <- sdlPollEvent
  case mev of
    Nothing -> pure []
    Just ev -> (ev :) <$> drainEvents

  - could also be
  unfoldM sqlPollEvent
  - but requires dependency on monad-loops
-}

-- | Drain the SDL event queue, preserving arrival order
drainEvents :: IO [SDLEvent]
drainEvents = sdlPollEvent >>= maybe (pure []) (\ev -> (ev :) <$> drainEvents)

drainActions :: IO [Action]
drainActions = mapMaybe toAction <$> drainEvents

toAction :: SDLEvent -> Maybe Action
toAction (SDLEventQuit _) = Just Quit
toAction (SDLEventKeyboard k)
  | sdlKeyboardType k == SDL_EVENT_KEY_DOWN && sdlKeyboardKey k == SDLKEscape = Just Quit
toAction _ = Nothing

apply :: World -> Action -> World
apply w Quit = w{quitting = True}
apply w _ = w

step :: Double -> World -> World
step _ w = w
