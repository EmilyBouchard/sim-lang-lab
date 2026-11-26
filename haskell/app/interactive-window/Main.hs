module Main (main) where

import Control.Applicative ((<|>))
import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Data.Maybe (mapMaybe)
import Data.Word (Word64)
import Foreign.C.Types (CUInt)
import SDL3 hiding (cos, info, round, sin, sqrt)

tail' :: [a] -> [a]
tail' = drop 1

-- | reciprocal of square root of 2 : 1 / (2^0.5)
rsqrt2 :: Double
rsqrt2 = 1 / sqrt 2

type Point = (Double, Double)

data Dir = DUp | DDown | DLeft | DRight

data Held = Held {heldUp, heldDown, heldLeft, heldRight :: Bool}

data Action = Quit | MouseTo Point | MoveInput Dir Bool

data Bouncing = Bouncing {bouncingRadius :: Double, bouncingPos :: Point, bouncingVel :: Point}

data World = World
  {quitting :: Bool, held :: Held, trianglePos :: Point, rectPos :: Point, bouncingCircle :: Bouncing}
defaultWorld :: World
defaultWorld =
  World
    { quitting = False
    , held = Held False False False False
    , trianglePos = (fromIntegral windowWidth / 2, fromIntegral windowHeight / 2)
    , rectPos = (100, 100)
    , bouncingCircle =
        Bouncing 50 (fromIntegral windowWidth / 2, fromIntegral windowHeight / 2) (160, 100)
    }

uv0 :: SDLFPoint
uv0 = SDLFPoint 0 0

pointToFPoint :: Point -> SDLFPoint
pointToFPoint (x, y) = SDLFPoint (realToFrac x) (realToFrac y)

pointToVertex :: Point -> SDLFColor -> SDLFPoint -> SDLVertex
pointToVertex p = SDLVertex (pointToFPoint p)

pointsToVertices :: [Point] -> SDLFColor -> [SDLVertex]
pointsToVertices xs c = map (\x -> pointToVertex x c uv0) xs

circleTriangles :: Point -> Double -> [Point]
circleTriangles (x, y) r = concatMap (\(p1, p2) -> [p1, p2, (x, y)]) rim
  where
    steps :: Int
    steps = 32
    angleStep = pi * 2 / fromIntegral steps
    pointN n = (x + r * cos (fromIntegral n * angleStep), y + r * sin (fromIntegral n * angleStep))
    rim = let xs = [pointN v | v <- [0 .. steps]] in zip xs (tail' xs)

trianglePoints :: Point -> Double -> [Point]
trianglePoints (x, y) r = [pointA (angleN n) | n <- [0 .. 3]]
  where
    angleN n = 3 * pi / 2 + n * (2 * pi / 3)
    pointA a = (x + r * cos a, y + r * sin a)

circleColor :: SDLFColor
circleColor = SDLFColor 0 0 1 1

rectSpeed :: Double
rectSpeed = 200

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

-- secondsToNs :: Double -> Word64
-- secondsToNs s = round (s * nsPerSecond)

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
        let circle =
              circleTriangles (bouncingPos . bouncingCircle $ world') (bouncingRadius . bouncingCircle $ world')
        let triangle = map pointToFPoint $ trianglePoints (trianglePos world') 30
        let (rx, ry) = rectPos world'
        _ <- sdlSetRenderDrawColor renderer 45 45 45 255 -- dark background
        _ <- sdlRenderClear renderer
        _ <- sdlRenderGeometry renderer Nothing (pointsToVertices circle circleColor) Nothing
        _ <- sdlSetRenderDrawColor renderer 0 255 0 255 -- green square
        _ <- sdlRenderFillRect renderer (Just $ SDLFRect (realToFrac rx) (realToFrac ry) 100 100)
        _ <- sdlSetRenderDrawColor renderer 255 0 0 255 -- red triangle
        _ <- sdlRenderLines renderer triangle
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
toAction (SDLEventKeyboard k) = actionFromKeyboard k
toAction (SDLEventMouseMotion m) = Just $ MouseTo (realToFrac (sdlMouseMotionX m), realToFrac (sdlMouseMotionY m))
toAction _ = Nothing

actionFromKeyboard :: SDLKeyboardEvent -> Maybe Action
actionFromKeyboard k
  | keyDown || keyUp = actionFromKeycode kc keyDown <|> actionFromScancode sc keyDown
  | otherwise = Nothing
  where
    keyDown = sdlKeyboardType k == SDL_EVENT_KEY_DOWN
    keyUp = sdlKeyboardType k == SDL_EVENT_KEY_UP
    kc = sdlKeyboardKey k
    sc = sdlKeyboardScancode k

actionFromKeycode :: SDLKeycode -> Bool -> Maybe Action
actionFromKeycode kc pressed = case kc of
  SDLKEscape -> Just Quit
  SDLKUp -> Just $ MoveInput DUp pressed
  SDLKDown -> Just $ MoveInput DDown pressed
  SDLKLeft -> Just $ MoveInput DLeft pressed
  SDLKRight -> Just $ MoveInput DRight pressed
  _ -> Nothing

actionFromScancode :: SDLScancode -> Bool -> Maybe Action
actionFromScancode sc state = case sc of
  SDL_SCANCODE_W -> Just $ MoveInput DUp state
  SDL_SCANCODE_A -> Just $ MoveInput DLeft state
  SDL_SCANCODE_S -> Just $ MoveInput DDown state
  SDL_SCANCODE_D -> Just $ MoveInput DRight state
  _ -> Nothing

apply :: World -> Action -> World
apply w Quit = w{quitting = True}
apply w (MouseTo p) = w{trianglePos = p}
apply w (MoveInput dir pressed) = case dir of
  DUp -> w{held = (held w){heldUp = pressed}}
  DDown -> w{held = (held w){heldDown = pressed}}
  DLeft -> w{held = (held w){heldLeft = pressed}}
  DRight -> w{held = (held w){heldRight = pressed}}

heldToDir :: Held -> Point
heldToDir (Held up down left right) = normalize (val right - val left, val down - val up)
  where
    val True = 1
    val False = 0
    normalize (x, y)
      | x /= 0 && y /= 0 = (x * rsqrt2, y * rsqrt2)
      | otherwise = (x, y)

step :: Double -> World -> World
step dt w = w{rectPos = rectPos', bouncingCircle = circle{bouncingPos = bouncingPos'}}
  where
    circle@(Bouncing _ (x, y) (vx, vy)) = bounce (bouncingCircle w)
    (rx, ry) = rectPos w
    (rdx, rdy) = heldToDir (held w)
    rectPos' = (rx + (rdx * dt * rectSpeed), ry + (rdy * dt * rectSpeed))
    bouncingPos' = (x + (vx * dt), y + (vy * dt))

bounce :: Bouncing -> Bouncing
bounce b@(Bouncing r (x, y) (vx, vy)) = b{bouncingVel = (vx', vy')}
  where
    vx' = reflect r (fromIntegral windowWidth - r) x vx
    vy' = reflect r (fromIntegral windowHeight - r) y vy

reflect :: Double -> Double -> Double -> Double -> Double
reflect lo hi pos vel
  | vel > 0 && pos > hi = -vel
  | vel < 0 && pos < lo = -vel
  | otherwise = vel
