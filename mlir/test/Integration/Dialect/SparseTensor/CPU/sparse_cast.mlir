// RUN: mlir-opt %s \
// RUN:   --sparsification --sparse-tensor-conversion \
// RUN:   --convert-vector-to-scf --convert-scf-to-std \
// RUN:   --func-bufferize --tensor-constant-bufferize --tensor-bufferize \
// RUN:   --std-bufferize --finalizing-bufferize --lower-affine \
// RUN:   --convert-vector-to-llvm --convert-memref-to-llvm \
// RUN:   --convert-std-to-llvm --reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner \
// RUN:  -e entry -entry-point-result=void  \
// RUN:  -shared-libs=%mlir_integration_test_dir/libmlir_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//
// Do the same run, but now with SIMDization as well. This should not change the outcome.
//
// RUN: mlir-opt %s \
// RUN:   --sparsification="vectorization-strategy=2 vl=2 enable-simd-index32" --sparse-tensor-conversion \
// RUN:   --convert-vector-to-scf --convert-scf-to-std \
// RUN:   --func-bufferize --tensor-constant-bufferize --tensor-bufferize \
// RUN:   --std-bufferize --finalizing-bufferize --lower-affine \
// RUN:   --convert-vector-to-llvm --convert-memref-to-llvm \
// RUN:   --convert-std-to-llvm --reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner \
// RUN:  -e entry -entry-point-result=void  \
// RUN:  -shared-libs=%mlir_integration_test_dir/libmlir_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//

#SV = #sparse_tensor.encoding<{ dimLevelType = [ "compressed" ] }>

#trait_cast = {
  indexing_maps = [
    affine_map<(i) -> (i)>,  // A (in)
    affine_map<(i) -> (i)>   // X (out)
  ],
  iterator_types = ["parallel"],
  doc = "X(i) = cast A(i)"
}

//
// Integration test that lowers a kernel annotated as sparse to actual sparse
// code, initializes a matching sparse storage scheme from a dense vector,
// and runs the resulting code with the JIT compiler.
//
module {
  //
  // Various kernels that cast a sparse vector from one type to another.
  // Standard supports the following casts.
  //   sitofp
  //   uitofp
  //   fptosi
  //   fptoui
  //   fpext
  //   fptrunc
  //   sexti
  //   zexti
  //   trunci
  //   bitcast
  // Since all casts are "zero preserving" unary operations, lattice computation
  // and conversion to sparse code is straightforward.
  //
  func @sparse_cast_s32_to_f32(%arga: tensor<10xi32, #SV>) -> tensor<10xf32> {
    %argx = constant dense<0.0> : tensor<10xf32>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xi32, #SV>)
      outs(%argx: tensor<10xf32>) {
        ^bb(%a: i32, %x : f32):
          %cst = sitofp %a : i32 to f32
          linalg.yield %cst : f32
    } -> tensor<10xf32>
    return %0 : tensor<10xf32>
  }
  func @sparse_cast_u32_to_f32(%arga: tensor<10xi32, #SV>) -> tensor<10xf32> {
    %argx = constant dense<0.0> : tensor<10xf32>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xi32, #SV>)
      outs(%argx: tensor<10xf32>) {
        ^bb(%a: i32, %x : f32):
          %cst = uitofp %a : i32 to f32
          linalg.yield %cst : f32
    } -> tensor<10xf32>
    return %0 : tensor<10xf32>
  }
  func @sparse_cast_f32_to_s32(%arga: tensor<10xf32, #SV>) -> tensor<10xi32> {
    %argx = constant dense<0> : tensor<10xi32>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xf32, #SV>)
      outs(%argx: tensor<10xi32>) {
        ^bb(%a: f32, %x : i32):
          %cst = fptosi %a : f32 to i32
          linalg.yield %cst : i32
    } -> tensor<10xi32>
    return %0 : tensor<10xi32>
  }
  func @sparse_cast_f64_to_u32(%arga: tensor<10xf64, #SV>) -> tensor<10xi32> {
    %argx = constant dense<0> : tensor<10xi32>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xf64, #SV>)
      outs(%argx: tensor<10xi32>) {
        ^bb(%a: f64, %x : i32):
          %cst = fptoui %a : f64 to i32
          linalg.yield %cst : i32
    } -> tensor<10xi32>
    return %0 : tensor<10xi32>
  }
  func @sparse_cast_f32_to_f64(%arga: tensor<10xf32, #SV>) -> tensor<10xf64> {
    %argx = constant dense<0.0> : tensor<10xf64>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xf32, #SV>)
      outs(%argx: tensor<10xf64>) {
        ^bb(%a: f32, %x : f64):
          %cst = fpext %a : f32 to f64
          linalg.yield %cst : f64
    } -> tensor<10xf64>
    return %0 : tensor<10xf64>
  }
  func @sparse_cast_f64_to_f32(%arga: tensor<10xf64, #SV>) -> tensor<10xf32> {
    %argx = constant dense<0.0> : tensor<10xf32>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xf64, #SV>)
      outs(%argx: tensor<10xf32>) {
        ^bb(%a: f64, %x : f32):
          %cst = fptrunc %a : f64 to f32
          linalg.yield %cst : f32
    } -> tensor<10xf32>
    return %0 : tensor<10xf32>
  }
  func @sparse_cast_s32_to_u64(%arga: tensor<10xi32, #SV>) -> tensor<10xi64> {
    %argx = constant dense<0> : tensor<10xi64>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xi32, #SV>)
      outs(%argx: tensor<10xi64>) {
        ^bb(%a: i32, %x : i64):
          %cst = sexti %a : i32 to i64
          linalg.yield %cst : i64
    } -> tensor<10xi64>
    return %0 : tensor<10xi64>
  }
  func @sparse_cast_u32_to_s64(%arga: tensor<10xi32, #SV>) -> tensor<10xi64> {
    %argx = constant dense<0> : tensor<10xi64>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xi32, #SV>)
      outs(%argx: tensor<10xi64>) {
        ^bb(%a: i32, %x : i64):
          %cst = zexti %a : i32 to i64
          linalg.yield %cst : i64
    } -> tensor<10xi64>
    return %0 : tensor<10xi64>
  }
  func @sparse_cast_i32_to_i8(%arga: tensor<10xi32, #SV>) -> tensor<10xi8> {
    %argx = constant dense<0> : tensor<10xi8>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xi32, #SV>)
      outs(%argx: tensor<10xi8>) {
        ^bb(%a: i32, %x : i8):
          %cst = trunci %a : i32 to i8
          linalg.yield %cst : i8
    } -> tensor<10xi8>
    return %0 : tensor<10xi8>
  }
  func @sparse_cast_f32_as_s32(%arga: tensor<10xf32, #SV>) -> tensor<10xi32> {
    %argx = constant dense<0> : tensor<10xi32>
    %0 = linalg.generic #trait_cast
      ins(%arga: tensor<10xf32, #SV>)
      outs(%argx: tensor<10xi32>) {
        ^bb(%a: f32, %x : i32):
          %cst = bitcast %a : f32 to i32
          linalg.yield %cst : i32
    } -> tensor<10xi32>
    return %0 : tensor<10xi32>
  }

  //
  // Main driver that converts a dense tensor into a sparse tensor
  // and then calls the sparse casting kernel.
  //
  func @entry() {
    %z = constant 0 : index
    %b = constant 0 : i8
    %i = constant 0 : i32
    %l = constant 0 : i64
    %f = constant 0.0 : f32
    %d = constant 0.0 : f64

    // Initialize dense tensors, convert to a sparse vectors.
    %0 = constant dense<[ -4, -3, -2, -1, 0, 1, 2, 3, 4, 305 ]> : tensor<10xi32>
    %1 = sparse_tensor.convert %0 : tensor<10xi32> to tensor<10xi32, #SV>
    %2 = constant dense<[ -4.4, -3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.3, 4.4, 305.5 ]> : tensor<10xf32>
    %3 = sparse_tensor.convert %2 : tensor<10xf32> to tensor<10xf32, #SV>
    %4 = constant dense<[ -4.4, -3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.3, 4.4, 305.5 ]> : tensor<10xf64>
    %5 = sparse_tensor.convert %4 : tensor<10xf64> to tensor<10xf64, #SV>
    %6 = constant dense<[ 4294967295.0, 4294967294.0, 4294967293.0, 4294967292.0,
                          0.0, 1.1, 2.2, 3.3, 4.4, 305.5 ]> : tensor<10xf64>
    %7 = sparse_tensor.convert %6 : tensor<10xf64> to tensor<10xf64, #SV>

    //
    // CHECK: ( -4, -3, -2, -1, 0, 1, 2, 3, 4, 305 )
    //
    %c0 = call @sparse_cast_s32_to_f32(%1) : (tensor<10xi32, #SV>) -> tensor<10xf32>
    %m0 = memref.buffer_cast %c0 : memref<10xf32>
    %v0 = vector.transfer_read %m0[%z], %f: memref<10xf32>, vector<10xf32>
    vector.print %v0 : vector<10xf32>

    //
    // CHECK: ( 4.29497e+09, 4.29497e+09, 4.29497e+09, 4.29497e+09, 0, 1, 2, 3, 4, 305 )
    //
    %c1 = call @sparse_cast_u32_to_f32(%1) : (tensor<10xi32, #SV>) -> tensor<10xf32>
    %m1 = memref.buffer_cast %c1 : memref<10xf32>
    %v1 = vector.transfer_read %m1[%z], %f: memref<10xf32>, vector<10xf32>
    vector.print %v1 : vector<10xf32>

    //
    // CHECK: ( -4, -3, -2, -1, 0, 1, 2, 3, 4, 305 )
    //
    %c2 = call @sparse_cast_f32_to_s32(%3) : (tensor<10xf32, #SV>) -> tensor<10xi32>
    %m2 = memref.buffer_cast %c2 : memref<10xi32>
    %v2 = vector.transfer_read %m2[%z], %i: memref<10xi32>, vector<10xi32>
    vector.print %v2 : vector<10xi32>

    //
    // CHECK: ( 4294967295, 4294967294, 4294967293, 4294967292, 0, 1, 2, 3, 4, 305 )
    //
    %c3 = call @sparse_cast_f64_to_u32(%7) : (tensor<10xf64, #SV>) -> tensor<10xi32>
    %m3 = memref.buffer_cast %c3 : memref<10xi32>
    %v3 = vector.transfer_read %m3[%z], %i: memref<10xi32>, vector<10xi32>
    %vu = vector.bitcast %v3 : vector<10xi32> to vector<10xui32>
    vector.print %vu : vector<10xui32>

    //
    // CHECK: ( -4.4, -3.3, -2.2, -1.1, 0, 1.1, 2.2, 3.3, 4.4, 305.5 )
    //
    %c4 = call @sparse_cast_f32_to_f64(%3) : (tensor<10xf32, #SV>) -> tensor<10xf64>
    %m4 = memref.buffer_cast %c4 : memref<10xf64>
    %v4 = vector.transfer_read %m4[%z], %d: memref<10xf64>, vector<10xf64>
    vector.print %v4 : vector<10xf64>

    //
    // CHECK: ( -4.4, -3.3, -2.2, -1.1, 0, 1.1, 2.2, 3.3, 4.4, 305.5 )
    //
    %c5 = call @sparse_cast_f64_to_f32(%5) : (tensor<10xf64, #SV>) -> tensor<10xf32>
    %m5 = memref.buffer_cast %c5 : memref<10xf32>
    %v5 = vector.transfer_read %m5[%z], %f: memref<10xf32>, vector<10xf32>
    vector.print %v5 : vector<10xf32>

    //
    // CHECK: ( -4, -3, -2, -1, 0, 1, 2, 3, 4, 305 )
    //
    %c6 = call @sparse_cast_s32_to_u64(%1) : (tensor<10xi32, #SV>) -> tensor<10xi64>
    %m6 = memref.buffer_cast %c6 : memref<10xi64>
    %v6 = vector.transfer_read %m6[%z], %l: memref<10xi64>, vector<10xi64>
    vector.print %v6 : vector<10xi64>

    //
    // CHECK: ( 4294967292, 4294967293, 4294967294, 4294967295, 0, 1, 2, 3, 4, 305 )
    //
    %c7 = call @sparse_cast_u32_to_s64(%1) : (tensor<10xi32, #SV>) -> tensor<10xi64>
    %m7 = memref.buffer_cast %c7 : memref<10xi64>
    %v7 = vector.transfer_read %m7[%z], %l: memref<10xi64>, vector<10xi64>
    vector.print %v7 : vector<10xi64>

    //
    // CHECK: ( -4, -3, -2, -1, 0, 1, 2, 3, 4, 49 )
    //
    %c8 = call @sparse_cast_i32_to_i8(%1) : (tensor<10xi32, #SV>) -> tensor<10xi8>
    %m8 = memref.buffer_cast %c8 : memref<10xi8>
    %v8 = vector.transfer_read %m8[%z], %b: memref<10xi8>, vector<10xi8>
    vector.print %v8 : vector<10xi8>

    //
    // CHECK: ( -1064514355, -1068289229, -1072902963, -1081291571, 0, 1066192077, 1074580685, 1079194419, 1082969293, 1134084096 )
    //
    %c9 = call @sparse_cast_f32_as_s32(%3) : (tensor<10xf32, #SV>) -> tensor<10xi32>
    %m9 = memref.buffer_cast %c9 : memref<10xi32>
    %v9 = vector.transfer_read %m9[%z], %i: memref<10xi32>, vector<10xi32>
    vector.print %v9 : vector<10xi32>

    return
  }
}
