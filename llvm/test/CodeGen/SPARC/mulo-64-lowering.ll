; RUN: llc -march=sparcv9 < %s | FileCheck %s

declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64)
declare { i64, i1 } @llvm.umul.with.overflow.i64(i64, i64)

; CHECK-LABEL: s:
; CHECK: save %sp, -176, %sp
; CHECK: srax %i0, 63, %o0
; CHECK: srax %i1, 63, %o2
; CHECK: mov     %i0, %o1
; CHECK: call __multi3
; CHECK: mov     %i1, %o3
; CHECK: ret
; CHECK-NEXT: restore %g0, %o1, %o0

define i64 @s(i64 %0, i64 %1) {
  %3 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %0, i64 %1)
  %4 = extractvalue { i64, i1 } %3, 0
  ret i64 %4
}

; CHECK-label: u:
; CHECK: save %sp, -176, %sp
; CHECK: mov     0, %o0
; CHECK: mov     %i0, %o1
; CHECK: mov     %o0, %o2
; CHECK: call __multi3
; CHECK: mov     %i1, %o3
; CHECK: ret
; CHECK-NEXT: restore %g0, %o1, %o0

define i64 @u(i64 %0, i64 %1) local_unnamed_addr #0 {
  %3 = call { i64, i1 } @llvm.umul.with.overflow.i64(i64 %0, i64 %1)
  %4 = extractvalue { i64, i1 } %3, 0
  ret i64 %4
}
