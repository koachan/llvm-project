;RUN: llc -mtriple=sparc < %s -verify-machineinstrs | FileCheck %s
;RUN: llc -mtriple=sparc -O0 < %s -verify-machineinstrs | FileCheck %s -check-prefix=UNOPT

target triple = "sparc-unknown-linux-gnu"

define i32 @test(i32 %a) #0 {
entry:
; CHECK: test
; CHECK: call bar
; CHECK-NOT: nop
; CHECK: ret
; CHECK-NEXT: restore
  %0 = tail call i32 @bar(i32 %a) nounwind
  ret i32 %0
}

define i32 @test_jmpl(ptr nocapture %f, i32 %a, i32 %b) #0 {
entry:
; CHECK:      test_jmpl
; CHECK:      call
; CHECK-NOT:  nop
; CHECK:      ret
; CHECK-NEXT: restore
  %0 = tail call i32 %f(i32 %a, i32 %b) nounwind
  ret i32 %0
}

define i32 @test_loop(i32 %a, i32 %b) nounwind readnone {
; CHECK: test_loop
entry:
  %0 = icmp sgt i32 %b, 0
  br i1 %0, label %bb, label %bb5

bb:                                               ; preds = %entry, %bb
  %a_addr.18 = phi i32 [ %a_addr.0, %bb ], [ %a, %entry ]
  %1 = phi i32 [ %3, %bb ], [ 0, %entry ]
  %tmp9 = mul i32 %1, %b
  %2 = and i32 %1, 1
  %tmp = xor i32 %2, 1
  %.pn = shl i32 %tmp9, %tmp
  %a_addr.0 = add i32 %.pn, %a_addr.18
  %3 = add nsw i32 %1, 1
  %exitcond = icmp eq i32 %3, %b
;CHECK:      cmp
;CHECK:      bne
;CHECK-NOT:  nop
  br i1 %exitcond, label %bb5, label %bb

bb5:                                              ; preds = %bb, %entry
  %a_addr.1.lcssa = phi i32 [ %a, %entry ], [ %a_addr.0, %bb ]
;CHECK:      retl
;CHECK-NOT: restore
  ret i32 %a_addr.1.lcssa
}

define i32 @test_inlineasm(i32 %a) #0 {
entry:
;CHECK-LABEL:      test_inlineasm:
;CHECK: cmp
;CHECK-NEXT: mov
;CHECK:      sethi
;CHECK:      !NO_APP
;CHECK-NEXT: ble
;CHECK-NEXT: nop
  tail call void asm sideeffect "sethi 0, %g0", ""() nounwind
  %0 = icmp slt i32 %a, 0
  br i1 %0, label %bb, label %bb1

bb:                                               ; preds = %entry
  %1 = tail call i32 (...) @foo(i32 %a) nounwind
  ret i32 %1

bb1:                                              ; preds = %entry
  %2 = tail call i32 @bar(i32 %a) nounwind
  ret i32 %2
}

declare i32 @foo(...)

declare i32 @bar(i32)


define i32 @test_implicit_def() #0 {
entry:
;UNOPT-LABEL:       test_implicit_def:
;UNOPT:       call func
;UNOPT-NEXT:  nop
  %0 = tail call i32 @func(ptr undef) nounwind
  ret i32 0
}


declare i32 @func(ptr)


define i32 @restore_add(i32 %a, i32 %b) {
entry:
;CHECK-LABEL:  restore_add:
;CHECK:  ret
;CHECK:  restore %o0, %i1, %o0
  %0 = tail call i32 @bar(i32 %a) nounwind
  %1 = add nsw i32 %0, %b
  ret i32 %1
}

define i32 @restore_add_imm(i32 %a) {
entry:
;CHECK-LABEL:  restore_add_imm:
;CHECK:  ret
;CHECK:  restore %o0, 20, %o0
  %0 = tail call i32 @bar(i32 %a) nounwind
  %1 = add nsw i32 %0, 20
  ret i32 %1
}

define i32 @restore_or(i32 %a) #0 {
entry:
;CHECK-LABEL:  restore_or:
;CHECK:  ret
;CHECK:  restore %g0, %o0, %o0
  %0 = tail call i32 @bar(i32 %a) nounwind
  ret i32 %0
}

define i32 @restore_or_imm(i32 %a) {
entry:
;CHECK-LABEL:  restore_or_imm:
;CHECK:  or %o0, 20, %i0
;CHECK:  ret
;CHECK-NOT:  restore %g0, %g0, %g0
;CHECK:  restore
  %0 = tail call i32 @bar(i32 %a) nounwind
  %1 = or i32 %0, 20
  ret i32 %1
}


define i32 @restore_sethi(i32 %a) {
entry:
;CHECK-LABEL: restore_sethi:
;CHECK-NOT: sethi  3
;CHECK: restore %g0, 3072, %o0
  %0 = tail call i32 @bar(i32 %a) nounwind
  %1 = icmp ne i32 %0, 0
  %2 = select i1 %1, i32 3072, i32 0
  ret i32 %2
}

define i32 @restore_sethi_3bit(i32 %a) {
entry:
;CHECK-LABEL: restore_sethi_3bit:
;CHECK: sethi  6
;CHECK-NOT: restore %g0, 6144, %o0
  %0 = tail call i32 @bar(i32 %a) nounwind
  %1 = icmp ne i32 %0, 0
  %2 = select i1 %1, i32 6144, i32 0
  ret i32 %2
}

define i32 @restore_sethi_large(i32 %a) {
entry:
;CHECK-LABEL: restore_sethi_large:
;CHECK: sethi  4000, %i0
;CHECK-NOT: restore %g0, %g0, %g0
;CHECK:     restore
  %0 = tail call i32 @bar(i32 %a) nounwind
  %1 = icmp ne i32 %0, 0
  %2 = select i1 %1, i32 4096000, i32 0
  ret i32 %2
}

attributes #0 = { nounwind "disable-tail-calls"="true" }
