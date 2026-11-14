{-# LANGUAGE BangPatterns #-}

module UnlambdaCompiler
  ( Expr(..)
  , Comb(..)
  , lowerAlgebra
  , abstract
  , compileExpr
  , emitUnlambda
  , emitBinaryBytes
  , emitArena
  ) where

import Data.Bits (shiftL, (.|.))
import qualified Data.Set as S
import Data.Word (Word8)

data Expr
  = Var String
  | Lam String Expr
  | App Expr Expr
  | Bit0
  | Bit1
  | Xor Expr Expr
  | And Expr Expr
  | Delay Expr
  | CallCC Expr
  deriving (Eq, Show)

data Comb
  = CI | CK | CS | CB | CC | CD | CCallCC | CV
  | CApp Comb Comb
  deriving (Eq, Show)

lowerAlgebra :: Expr -> Expr
lowerAlgebra expr = case expr of
  Var x     -> Var x
  Lam x e   -> Lam x (lowerAlgebra e)
  App f x   -> App (lowerAlgebra f) (lowerAlgebra x)
  Bit0      -> Lam "x" (Lam "y" (Var "y"))
  Bit1      -> Lam "x" (Lam "y" (Var "x"))
  Xor a b   ->
    let zero = lowerAlgebra Bit0
        one  = lowerAlgebra Bit1
        a'   = lowerAlgebra a
        b'   = lowerAlgebra b
    in App (App a' (App (App b' zero) one)) (App (App b' one) zero)
  And a b   ->
    let zero = lowerAlgebra Bit0
    in App (App (lowerAlgebra a) (lowerAlgebra b)) zero
  Delay e   -> App (Var "#d") (lowerAlgebra e)
  CallCC e  -> App (Var "#c") (lowerAlgebra e)

data OpenComb
  = OVar String
  | OComb Comb
  | OApp OpenComb OpenComb
  deriving (Eq, Show)

openFV :: OpenComb -> S.Set String
openFV (OVar v)   = S.singleton v
openFV (OComb _)  = S.empty
openFV (OApp f x) = S.union (openFV f) (openFV x)

abstractVar :: String -> OpenComb -> OpenComb
abstractVar x term = case term of
  OVar y
    | x == y    -> OComb CI
    | otherwise -> OApp (OComb CK) (OVar y)
  OComb c       -> OApp (OComb CK) (OComb c)
  OApp m n ->
    let inM = S.member x (openFV m)
        inN = S.member x (openFV n)
    in case (inM, inN, n) of
         (False, True, OVar y) | x == y -> m
         (False, False, _) -> OApp (OComb CK) (OApp m n)
         (False, True, _)  -> OApp (OApp (OComb CB) m) (abstractVar x n)
         (True, False, _)  -> OApp (OApp (OComb CC) (abstractVar x m)) n
         (True, True, _)   -> OApp (OApp (OComb CS) (abstractVar x m)) (abstractVar x n)

toOpenComb :: Expr -> OpenComb
toOpenComb expr = case expr of
  Var "#d" -> OComb CD
  Var "#c" -> OComb CCallCC
  Var v    -> OVar v
  App f x  -> OApp (toOpenComb f) (toOpenComb x)
  Lam x e  -> abstractVar x (toOpenComb e)
  other    -> toOpenComb (lowerAlgebra other)

closeComb :: OpenComb -> Comb
closeComb (OComb c)  = c
closeComb (OApp f x) = CApp (closeComb f) (closeComb x)
closeComb (OVar v)   = error ("Unbound free variable in closed term: " ++ v)

abstract :: Expr -> Comb
abstract = closeComb . toOpenComb . lowerAlgebra

compileExpr :: Expr -> Comb
compileExpr = abstract

emitUnlambda :: Comb -> String
emitUnlambda c = case c of
  CI       -> "i"
  CK       -> "k"
  CS       -> "s"
  CD       -> "d"
  CCallCC  -> "c"
  CV       -> "v"
  CB       -> "``s`ksk"
  CC       -> "``s``s`k``s`ksks`kk"
  CApp f x -> '`' : emitUnlambda f ++ emitUnlambda x

emitOpcodes :: Comb -> [Word8]
emitOpcodes c = case c of
  CApp f x -> 0x00 : emitOpcodes f ++ emitOpcodes x
  CI       -> [0x01]
  CK       -> [0x02]
  CS       -> [0x03]
  CB       -> [0x04]
  CC       -> [0x05]
  CD       -> [0x06]
  CCallCC  -> [0x07]
  CV       -> [0x07]

emitBinaryBytes :: Comb -> [Word8]
emitBinaryBytes comb = packBits 0 0 (emitOpcodes comb)
  where
    packBits !acc !bitPos []
      | bitPos == 0 = []
      | otherwise   = [acc]
    packBits !acc !bitPos (op:ops)
      | bitPos <= 5 =
          let !acc' = acc .|. (op `shiftL` bitPos)
          in if bitPos + 3 == 8
             then acc' : packBits 0 0 ops
             else packBits acc' (bitPos + 3) ops
      | otherwise =
          let !lowBits  = 8 - bitPos
              !byteOut  = acc .|. (op `shiftL` bitPos)
              !nextAcc  = op `div` (1 `shiftL` lowBits)
          in byteOut : packBits nextAcc (3 - lowBits) ops

emitArena :: Comb -> ([(Int, Int)], Int)
emitArena comb = go comb []
  where
    primCode CI = -1; primCode CK = -2; primCode CS = -3
    primCode CB = -4; primCode CC = -5; primCode CD = -6
    primCode CCallCC = -7; primCode CV = -8; primCode _ = 0
    go (CApp f x) arena =
      let (arena1, idxL) = case f of CApp _ _ -> go f arena; p -> (arena, primCode p)
          (arena2, idxR) = case x of CApp _ _ -> go x arena1; p -> (arena1, primCode p)
          !newIdx = length arena2
      in (arena2 ++ [(idxL, idxR)], newIdx)
    go p arena = (arena, primCode p)
