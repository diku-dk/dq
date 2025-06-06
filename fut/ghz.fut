-- Quantum benchmark: GHZ (Greenberger–Horne–Zeilinger state)
-- Desc: Data-parallel simulation of establishing the GHZ state
-- Spec: main(n): For n qubits, perform an extangled state
--       between the zero-state and the 1-state.
-- Origin: Ported from Supermarq

import "dqfut"
open mk_gates(f64)

-- return probabilities of states |0..0> and |1..1>
def ghz n : (f64, f64) =
  let s = fromKet (replicate n 0)
          |*> gateH 0
          |*> repeat (n-1) (cntrlX 1)
  let d = dist s
  in (d[0].1, d[2**n-1].1)

def approx a b = f64.abs(a-b) < 0.01

entry ghz_test (n:i64) : (f64,f64) =
  ghz n

def main n =
  let (a,b) = ghz n
  in approx a 0.5 && approx b 0.5

-- ==
-- entry: ghz_test
-- nobench input { 8i64 }
-- output { 0.5f64 0.5f64 }
-- nobench input { 12i64 }
-- output { 0.5f64 0.5f64 }

-- ==
-- entry: main
-- input { 8i64 } output { true }
-- input { 12i64 } output { true }
-- notest input { 13i64 } output { true }
-- notest input { 14i64 } output { true }
-- notest input { 15i64 } output { true }
-- notest input { 17i64 } output { true }
-- notest input { 18i64 } output { true }
-- notest input { 19i64 } output { true }
-- notest input { 20i64 } output { true }
-- notest input { 21i64 } output { true }
-- notest input { 22i64 } output { true }
-- notest input { 23i64 } output { true }
-- notest input { 24i64 } output { true }
-- notest input { 25i64 } output { true }
-- notest input { 26i64 } output { true }
-- notest input { 27i64 } output { true }

-- disable input { 28i64 } output { true }
-- disable input { 29i64 } output { true }
-- disable input { 30i64 } output { true }
