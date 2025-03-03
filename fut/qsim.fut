import "lib/github.com/diku-dk/complex/complex"

module type gates = {
  type c              -- type of complex numbers
  type q = i64        -- qubit index

  type^ gate_snd = c -> c                                      -- C -> C; gate on the form [[1,0],[0,a]]
  type^ gate = c -> c -> (c,c)                                 -- C^2 -> C^2
  type^ gate2 = c -> c -> c -> c -> (c,c,c,c)                  -- C^4 -> C^4

  type st[n] = [2**n]c

  val gate_sndC [n] : (m:i64) -> q -> gate_snd -> *st[n] -> *st[n]  -- S, ...
  val gateC     [n] : (m:i64) -> q -> gate -> *st[n] -> *st[n]      -- X, H, ...
  val gate2     [n] : q -> gate2 -> *st[n] -> *st[n]                -- e.g., swap

  val gateX   [n] : q -> *st[n] -> *st[n]                      -- 0 <= q < n
  val gateY   [n] : q -> *st[n] -> *st[n]                      -- 0 <= q < n
  val gateZ   [n] : q -> *st[n] -> *st[n]                      -- 0 <= q < n
  val gateH   [n] : q -> *st[n] -> *st[n]                      -- 0 <= q < n
  val gateT   [n] : q -> *st[n] -> *st[n]                      -- 0 <= q < n
  val gateR   [n] : f64 -> q -> *st[n] -> *st[n]               -- 0 <= q < n

  val cntrlX  [n] : (m:i64) -> q -> *st[n] -> *st[n]           -- 0 <= q < n - m
  val cntrlY  [n] : (m:i64) -> q -> *st[n] -> *st[n]           -- 0 <= q < n - m
  val cntrlZ  [n] : (m:i64) -> q -> *st[n] -> *st[n]           -- 0 <= q < n - m
  val cntrlH  [n] : (m:i64) -> q -> *st[n] -> *st[n]           -- 0 <= q < n - m
  val cntrlT  [n] : (m:i64) -> q -> *st[n] -> *st[n]           -- 0 <= q < n - m
  val cntrlR  [n] : (m:i64) -> f64 -> q -> *st[n] -> *st[n]    -- 0 <= q < n - m

  val swap    [n] : q -> *st[n] -> *st[n]                      -- 0 <= q < n - 1
  val swap2   [n] : (q:q) -> (r:q) -> *st[n] -> *st[n]         -- 0 <= q < n - 1, q < r < n

  type ket[n] = [n]i64
  val fromKet [n] : ket[n] -> *st[n]
  val toKet       : (n:i64) -> (i:i64) -> ket[n]

  type dist[n] = [2**n](ket[n],f64)

  val dist    [n] : st[n] -> dist[n]
  val distmax [n] : dist[n] -> (ket[n],f64)

  -- Some utility functions
  val <*<      'a : (q -> *a -> *a) -> (q -> *a -> *a) -> (q -> *a -> *a)
  val >*>      'a : (q -> *a -> *a) -> (q -> *a -> *a) -> (q -> *a -> *a)
  val repeat   'a : i64 -> (i64 -> *a -> *a) -> *a -> *a
}


module complex = mk_complex (f64)

module gates : gates with c = complex.complex = {
  type c = complex.complex
  type q = i64

  type^ gate_snd = c -> c
  type^ gate = c -> c -> (c,c)
  type^ gate2 = c -> c -> c -> c -> (c,c,c,c)

  type st[n] = [2**n]c

  def i = complex.mk_im 1.0
  def ni = complex.mk_im (-1.0)
  def rsqrt2 = complex.mk_re (1.0 / f64.sqrt 2.0)
  def ipi4 = complex.mk_im (f64.pi / 4)
  def eipi4 = complex.(exp ipi4)

  def X a b = (b, a)
  def Y a b = complex.((ni*b, i*a))
  def Z a b = complex.((a, neg b))
  def H a b = complex.((a*rsqrt2+b*rsqrt2, a*rsqrt2-b*rsqrt2))
  def T a b = complex.((a, b*eipi4))
  def R phi a b = complex.((a, b*exp(mk_im phi)))

  def dst (n:i64) (q:i64) : i64 = 2**(n-q-1)

  def gate_old [n] (q:q) (g:gate) (v: *st[n]) : *st[n] =
    let d = dst n q
    let v = v :> *[(2**q*2)*d]c
    let v : *[2**q][2][d]c = unflatten (unflatten v)
    let v : *[2**q][d][2]c = map transpose v
    let v = map (map (\p -> let (x,y) = g p[0] p[1]
                            in [x,y])) v
    let v = map transpose v
    in flatten (flatten v) :> *st[n]

  def vec 'a [m][n] (x:*[m][n]a) : *[n*m]a =
    flatten(transpose x)

  def unvec 'a [m][n] (x:*[m*n]a) : *[n][m]a =
    transpose(unflatten x)

  def gate [n] (q:q) (g:gate) (v: *st[n]) : *st[n] =
    let v = v :> *[(2**q*2)*2**(n-q-1)]c
    let f u = flatten(map (\p -> let (x,y) = g p[0] p[1]
                                 in [x,y]) (unflatten u))
    in vec(map f (unvec v)) :> *st[n]

  def gate_snd [n] (q:q) (g:gate_snd) (v: *st[n]) : *st[n] = -- e.g., for Z
    let v = v :> *[(2**q*2)*2**(n-q-1)]c
    let f u = flatten(map (\p -> [p[0],g p[1]]) (unflatten u))
    in vec(map f (unvec v)) :> *st[n]

  def gateC [n] (c:i64) (q:q) (g:gate) (v: *st[n]) : *st[n] =
    let d = dst n (q+c)
    let xs = map (\i -> map (\j -> 2*d*((i+1) * 2**c - 1) + j) (iota d)
                 ) (iota (2**q)) |> flatten
    let ys = map (\x -> x+d) xs
    let ccs = map2 (\x y -> g v[x] v[y]) xs ys
    in scatter v (xs++ys) (map (.0) ccs ++ map (.1) ccs)

  def gate_sndC [n] (c:i64) (q:q) (g:gate_snd) (v: *st[n]) : *st[n] =
    let d = dst n (q+c)
    let xs = map (\i -> map (\j -> 2*d*((i+1) * 2**c - 1) + j + d) (iota d)
                 ) (iota (2**q)) |> flatten
    let ccs = map (\x -> g v[x]) xs
    in scatter v xs ccs

  def gate2 [n] (q:q) (g:gate2) (v: *st[n]) : *st[n] =
    let v = v :> *[(2**q*4)*2**(n-q-2)]c
    let f u = flatten(map (\p -> let (a,b,c,d) = g p[0] p[1] p[2] p[3]
                                 in [a,b,c,d]) (unflatten u))
    in vec(map f (unvec v)) :> *st[n]

  -- def gate2 [n] (q:q) (g:gate2) (v: *st[n]) : *st[n] =
  --   let d = dst n (q+1)
  --   let xs = map (\i -> map (\j -> 4*d*i+j) (iota d)
  --                ) (iota (2**q)) |> flatten
  --   let ys = map (\x -> (x+d,x+d+d,x+d+d+d)) xs
  --   let ccs = map2 (\x y -> g v[x] v[y.0] v[y.1] v[y.2]) xs ys
  --   in scatter v (xs++map(.0)ys++map(.1)ys++map(.2)ys)
  --              (map(.0)ccs++map(.1)ccs++map(.2)ccs++map(.3)ccs)

  def swap [n] (q:q) (v: *st[n]) : *st[n] =
    gate2 q (\a b c d -> (a,c,b,d)) v

  -- def swap [n] (q:q) (v: *st[n]) : *st[n] =
  --   let v = v :> *[(2**q*4)*2**(n-q-2)]c
  --   let g p = let x = p[1]
  --             in copy p with [2] = x
  --                       with [1] = p[2]
  --   let f u = flatten(map g (unflatten u))
  --   in vec(map f (unvec v)) :> *st[n]

  def mymap 'a 'b [n] (f : *a -> *b) (v:*[n]a) : *[n]b =
    map (\u : *b -> f (copy u)) v

  def up [k] (q:q) (r:q) (v:*st[k]) : *st[k] =         -- 0 <= q < n - 1, q < r < n
    let n = r-q
    let v = v :> *[2**(r+1)*2**(k-r-1)]c
    let up (u : *[2**(n+1)]c) : *[2**n*2]c =
      let u = u :> *[2*2**n]c
      in flatten(unvec u)
    let f (u : *[2**(r+1)]c) : *[2**q*(2**n*2)]c =
      let u = u :> *[2**q*2**(n+1)]c
      in flatten(mymap up (unflatten u))
    in vec(mymap f (unvec v)) :> *st[k]

  def down [k] (q:q) (r:q) (v:*st[k]) : *st[k] =         -- 0 <= q < n - 1, q < r < n
    let n = r-q
    let v = v :> *[2**(r+1)*2**(k-r-1)]c
    let dn (u : *[2**(n+1)]c) : *[2*2**n]c =
      let u = u :> *[2**n*2]c
      in flatten(unvec u)
    let f (u : *[2**(r+1)]c) : *[2**q*(2*2**n)]c =
      let u = u :> *[2**q*2**(n+1)]c
      in flatten(mymap dn (unflatten u))
    in vec(mymap f (unvec v)) :> *st[k]

  def swap2 [k] (q:q) (r:q) (v:*st[k]) : *st[k] =
    down q r (up q (r-1) v)

  -- Non-scatter optimal version - however, the copy is very bad if c is large
  -- I would like map to support that if p is unique then the updates can be
  -- implemented in-place...
  --
  -- Here Futhark suffers from the rule that "A function that consumes one of
  -- its arguments may not be passed as a higher-order argument to another
  -- function..."

  def gateC_new [n] (c:i64) (q:q) (g:gate) (v: *st[n]) : *st[n] =
    let v = v :> *[(2**q*2**(c+1))*2**(n-q-c-1)]c
    let f u = flatten(map (\(p:[2**(c+1)]c) ->
                             let i = 2**(c+1)-2
                             let (x,y) = g p[i] p[i+1]
                             in copy p with [i] = x
				       with [i+1] = y)
                          (unflatten u))
    in vec(map f (unvec v)) :> *st[n]

  def gateC_new' [n] (c:i64) (q:q) (g:gate) (v: *st[n]) : *st[n] =
    let v = v :> *[(2**q*2**(c+1))*2**(n-q-c-1)]c
    let f (u : [2**q*2**(c+1)]c) =
      let u2 : [2**q][2**(c+1)]c = unflatten (copy u)
      let p2 : [2**q][2]c = map (\p -> let i = 2**(c+1)-2
				       let (x,y) = g p[i] p[i+1]
				       in [x,y])
				u2
      let u2[:,:-2] = p2
      in flatten u2
    in vec(map f (unvec v)) :> *st[n]

  -- The following version is the same as the above - but it results in a buggy
  -- execution if the function is used as a replacement of gateC. Executing
  -- "futhark test qsim_test.fut" issues errors whereas "futhark test -i
  -- qsim_test.fut" does not.

  def gateC_newinternalbug [n] (c:i64) (q:q) (g:gate) (v: *st[n]) : *st[n] =
    let v = v :> *[(2**q*2**(c+1))*2**(n-q-c-1)]c
    let f u = flatten(map (\p -> let i = 2**(c+1)-2
				 let (x,y) = g p[i] p[i+1]
				 in copy p with [i] = x
					   with [i+1] = y)
                          (unflatten u))
    in vec(map f (unvec v)) :> *st[n]

  def cntrlX [n] (m:i64) (q:q) (v: *st[n]) : *st[n] =
    gateC m q X v

  def cntrlY [n] (m:i64) (q:q) (v: *st[n]) : *st[n] =
    gateC m q Y v

  def cntrlZ [n] (m:i64) (q:q) (v: *st[n]) : *st[n] =
    gateC m q Z v

  def cntrlH [n] (m:i64) (q:q) (v: *st[n]) : *st[n] =
    gateC m q H v

  def cntrlT [n] (m:i64) (q:q) (v: *st[n]) : *st[n] =
    gateC m q T v

  def cntrlR [n] (m:i64) (p:f64) (q:q) (v: *st[n]) : *st[n] =
    gateC m q (R p) v

  def gateX [n] (q:q) (v: *st[n]) : *st[n] =
    gate q X v

  def gateY [n] (q:q) (v: *st[n]) : *st[n] =
    gate q Y v

  def gateZ [n] (q:q) (v: *st[n]) : *st[n] =
    gate_snd q (complex.neg) v

  def gateH [n] (q:q) (v: *st[n]) : *st[n] =
    gate q H v

  def gateT [n] (q:q) (v: *st[n]) : *st[n] =
    gate_snd q (\c -> complex.(c*eipi4)) v

  def gateR [n] (p:f64) (q:q) (v: *st[n]) : *st[n] =
    gate_snd q (\c -> complex.(c*exp(mk_im p))) v

  type ket [n] = [n]i64

  def fromKet [n] (xs:[n]i64) : *st[n] =
    let j = map2 (\x i -> x * 2**i) xs (reverse(iota n))
            |> reduce (+) 0
    in map (\i -> complex.mk_re(if i==j then 1 else 0))
           (iota (2**n))

  def toKet (n:i64) (i:i64) : ket[n] =
    let res : *[n]i64 = replicate n 0
    let (res,_) = loop (r,k) = (res,i) for j < n do
                    if k % 2 == 0
                    then (r with [n-j-1] = 0, k / 2)
                    else (r with [n-j-1] = 1, k / 2)
    in res

  def sq x : f64 = x*x

  def dist0 [m] (v:[m]c) : [m]f64 =
    map (sq <-< complex.mag) v

  type dist[n] = [2**n](ket[n],f64)

  def dist [n] (v:st[n]) : dist[n] =
    map2 (\i p -> (toKet n i, p)) (iota (2**n)) (dist0 v)

  def distmax [n] (d:dist[n]) =
    reduce (\x y -> if x.1 > y.1 then x else y) d[0] d

  def repeat 'a n (f : i64 -> *a -> *a) (s:*a) : *a =
    loop s = s for i in 0..<n do f i s

  def (<*<) 'a (f:q -> *a -> *a) (g:q -> *a -> *a) : q -> *a -> *a =
    \q (v:*a) : *a -> f q (g q v)

  def (>*>) 'a (f:q -> *a -> *a) (g:q -> *a -> *a) : q -> *a -> *a =
    \q (v:*a) : *a -> g q (f q v)
}
