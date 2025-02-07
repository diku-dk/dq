-- Data-parallel simulation of Grover's algorithm in Futhark

import "qsim"

open gates

def repeat [n] b e (f : i64 -> *st[n] -> *st[n]) (s:*st[n]) : *st[n] =
  loop s = s for i in b..<e do f i s

-- Some manual gate-fusion
def gateHX [n] q (v:*st[n]) = gateX q (gateH q v)
def gateXH [n] q (v:*st[n]) = gateH q (gateX q v)

def grover_diff [n] (s:*st[n]) : *st[n] =
  let s = repeat 0 n gateHX s
  let s = gateH (n-1) s
  let s = cntrlX (n-1) 0 s
  let s = gateH (n-1) s
  let s = repeat 0 n gateXH s
  in s

def encodeNum [n] (i:i64) (s:*st[n]) : *st[n] =
  (loop (s,n,i) = (s,n,i) while n > 0 do
     if i % 2 == 0 then (gateX (n-1) s, n-1, i/2)
     else (s,n-1,i/2)
  ).0

def oracle [n] i (s:*st[n]) : *st[n] =
  let s = encodeNum i s
  let s = cntrlZ (n-1) 0 s
  in encodeNum i s

def grover (n:i64) (i:i64) : (ket[n], f64) =
  let k = i64.f64(f64.ceil(f64.sqrt(f64.i64(2**n) * f64.pi / 4)))
  let s = fromKet (replicate n 0)
  let s = repeat 0 n gateH s
  let s = repeat 0 k (\_ (s:*st[n]) : *st[n] ->
			let s = oracle i s
			in grover_diff s) s
  let (k,p) = dist s |> distmax
  in (k,p)

-- Grover's algorithm searches for the index where the oracle
-- returns 1, which it does for the binary encoding of the
-- integer argument 12 (< 2**n). See tests below...

def main n = grover n 12

entry test_grover n i = (grover n i).0

-- ==
-- entry: test_grover
-- input { 8i64 12i64 }
-- output { [0i64, 0i64, 0i64, 0i64, 1i64, 1i64, 0i64, 0i64] }
-- input { 9i64 13i64 }
-- output { [0i64, 0i64, 0i64, 0i64, 0i64, 1i64, 1i64, 0i64, 1i64] }
