signature COMP = sig
  val circuitToFutFunBind : string -> Circuit.t -> string
  val circuitToFutMatBind : string -> Circuit.t -> string
  val preludeBindings : unit -> string
end

structure Comp :> COMP = struct

  infix |> fun x |> f = f x

  structure C = Complex
  structure M = Matrix
  structure F = Futhark

  fun pow2 n = if n <= 0 then 1 else 2 * pow2(n-1)

  type complex = C.complex
  type mat = C.complex M.t

  fun pp_c (c:complex) : string =
      C.fmtBrief (StringCvt.GEN(SOME 4)) c

  fun pp_r (r:real) =
      let val s = Real.toString r
      in if String.isSuffix ".0" s then String.extract(s,0,SOME(size s-2))
         else s
      end

  fun comp (t:Circuit.t) : Futhark.exp Futhark.M =
      let open Circuit
          open Futhark infix >>=
      in case t of
             I => ret (APP("I",[]))
           | X => ret (APP("X",[]))
           | Y => ret (APP("Y",[]))
           | Z => ret (APP("Z",[]))
           | H => ret (APP("H",[]))
           | T => ret (APP("T",[]))
           | S => ret (APP("S",[]))
           | SX => ret (APP("SX",[]))
           | SY => ret (APP("SY",[]))
           | SZ => ret (APP("SZ",[]))
           | SW => ret (APP("SW",[]))
           | Seq(t1,t2) =>
             comp t1 >>= (fn e1 =>
             comp t2 >>= (fn e2 =>
             let val n = Int.toString (pow2 (height t))
                 val ty = "[" ^ n ^ "][" ^ n ^ "]C.complex"
             in ret (TYPED(APP("matmul", [e2,e1]),ty))
             end))
           | Tensor(t1,t2) =>
             comp t1 >>= (fn e1 =>
             comp t2 >>= (fn e2 =>
             let val n = Int.toString (pow2 (height t))
                 val ty = "[" ^ n ^ "][" ^ n ^ "]C.complex"
             in ret (TYPED(APP("tensor", [e1,e2]),ty))
             end))
           | C t' => comp t' >>= (fn e =>
             let val n = Int.toString (pow2 (height t))
                 val ty = "[" ^ n ^ "][" ^ n ^ "]C.complex"
             in ret (TYPED(APP("control",[e]),ty))
             end)
      end

  fun vecTyFromHeight d =
      "[" ^ Int.toString(pow2 d) ^ "]C.complex"

  local
    open F infix >>=

    fun allI (t:Circuit.t) : bool =
        let open Circuit
        in case t of
               I => true
             | Tensor(a,b) => allI a andalso allI b
             | Seq(a,b) => allI a andalso allI b
             | _ => false
        end
    fun FunC A (f:F.exp -> F.exp F.M) : F.var option F.M =
        if allI A then ret NONE
        else let val ty = vecTyFromHeight (Circuit.height A)
             in Fun f ty ty >>= (ret o SOME)
             end
    fun splitF d v =
        let val ty = "[" ^ Int.toString (pow2 d) ^ "+" ^
                     Int.toString (pow2 d) ^ "]C.complex"
        in APP("split",[TYPED(v,ty)])
        end
    fun concatF d a b = TYPED(APP("concat",[a,b]),vecTyFromHeight d)
    fun unvecF (e,ty) = APP("unvec", [TYPED(e,ty)])
    fun vecF e = APP("vec",[e])
    fun mapF f e = APP("map", [VAR f,e])
    fun matvecmulF m v = APP("matvecmul", [m,v])
    fun transposeF m = APP("transpose", [m])
    fun mapF' NONE e = e
      | mapF' (SOME f) e = mapF f e
  in
    fun icomp (t:Circuit.t) (v:exp) : exp M =
        case t of
            Circuit.I => ret v
          | Circuit.Seq(t1,t2) => icomp t1 v >>= (icomp t2)
          | Circuit.C t' =>
            Let (splitF (Circuit.height t') v) >>= (fn p =>
            icomp t' (SEL(1,VAR p)) >>= (fn v1 =>
            ret (concatF (Circuit.height t) (SEL(0,VAR p)) v1)))
          | Circuit.Tensor(A,B) =>
            FunC A (icomp A) >>= (fn Af =>
            FunC B (icomp B) >>= (fn Bf =>
            let val dA = pow2(Circuit.height A)
                val dB = pow2(Circuit.height B)
                val ty = "[" ^ Int.toString dA ^ "*" ^
                         Int.toString dB ^ "]C.complex"
            in Let (unvecF(v,ty)) >>= (fn V =>
               Let (mapF' Bf (transposeF (VAR V))) >>= (fn W =>
               Let (mapF' Af (transposeF (VAR W))) >>= (fn Y =>
               ret (TYPED(vecF (VAR Y),vecTyFromHeight (Circuit.height t))))))
            end))
          | Circuit.X => ret (matvecmulF (APP("X",[])) v)
          | Circuit.Y => ret (matvecmulF (APP("Y",[])) v)
          | Circuit.Z => ret (matvecmulF (APP("Z",[])) v)
          | Circuit.H => ret (matvecmulF (APP("H",[])) v)
          | Circuit.T => ret (matvecmulF (APP("T",[])) v)
          | Circuit.S => ret (matvecmulF (APP("S",[])) v)
          | Circuit.SX => ret (matvecmulF (APP("SX",[])) v)
          | Circuit.SY => ret (matvecmulF (APP("SY",[])) v)
          | Circuit.SZ => ret (matvecmulF (APP("SZ",[])) v)
          | Circuit.SW => ret (matvecmulF (APP("SW",[])) v)
  end

  val prelude : unit F.M =
      let open F infix >>=
          val c0 = APP("C.i64",[CONST "0"])
          val c1 = APP("C.i64",[CONST "1"])
          val cn1 = APP("C.i64", [CONST "(-1)"])
          val ci = APP("C.mk_im",[CONST "1"])
          val cni = APP("C.mk_im", [CONST "(-1)"])
          val rsqrt2 = APP("C.mk_re", [CONST "(1.0 / f64.sqrt(2.0))"])
          val rnsqrt2 = APP("C.mk_re", [CONST "((-1.0) / f64.sqrt(2.0))"])
          val eipi4 = APP("C.exp", [APP("C.mk_im",[CONST "(f64.pi/4)"])])
          val c1pi = APP("C.+", [c1,ci])
          val c1mi = APP("C.-", [c1,ci])
          val halfc1pi = APP("C./", [c1pi,CONST "2"])
          val halfcn1mi = APP("C.-", [halfc1pi])
          fun ty n = "[" ^ Int.toString n ^ "][" ^ Int.toString n ^ "]C.complex"
          fun binds nil = ret ()
            | binds ((s,n,e)::rest) =
              FunNamed s (fn _ => ret e) "()" (ty n) >>= (fn _ => binds rest)
          val Se = ARR[ARR[c1,c0], ARR[c0,ci]]
      in binds [("I", 2, ARR[ARR[c1,c0],
                             ARR[c0,c1]]),
                ("X", 2, ARR[ARR[c0,c1],
                             ARR[c1,c0]]),
                ("Y", 2, ARR[ARR[c0,cni],
                             ARR[ci,c0]]),
                ("Z", 2, ARR[ARR[c1,c0],
                             ARR[c0,cn1]]),
                ("H", 2, ARR[ARR[rsqrt2,rsqrt2],
                             ARR[rsqrt2,rnsqrt2]]),
                ("T", 2, ARR[ARR[c1,c0],
                             ARR[c0,eipi4]]),
                ("S", 2, Se),
                ("SX", 2, ARR[ARR[c1pi,c1mi],
                              ARR[c1mi,c1pi]]),
                ("SY", 2, ARR[ARR[halfc1pi,halfcn1mi],
                              ARR[halfc1pi,halfc1pi]]),
                ("SZ", 2, Se),
                ("SW", 4, ARR[ARR[c1,c0,c0,c0],
                              ARR[c0,c0,c1,c0],
                              ARR[c0,c1,c0,c0],
                              ARR[c0,c0,c0,c1]])
               ]
      end

  fun circuitToFutMatBind (var:string) (t:Circuit.t) : string =
      let open F infix >>=
      in runBinds (comp t >>= (fn e =>
                   LetNamed var e >>= (fn _ =>
                   ret ())))
      end

  fun circuitToFutFunBind (f:string) (t:Circuit.t) : string =
      let open F infix >>=
          val ty = vecTyFromHeight (Circuit.height t)
      in runBinds (FunNamed f (icomp t) ty ty >>= (fn _ =>
                   ret()))
      end

  fun preludeBindings () : string =
      F.runBinds prelude

end
