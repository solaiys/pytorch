#include <THC/THCBlas.h>
#include <THC/THCGeneral.h>
#include <TH/THHalf.h>
#include <ATen/cuda/CUDAContext.h>
#include <ATen/cuda/CUDABlas.h>

#include <algorithm>
#include <mutex>

#ifdef __HIP_PLATFORM_HCC__
#include <hip/hip_version.h>
#define PYTORCH_ROCBLAS_VERSION_DECIMAL (ROCBLAS_VERSION_MAJOR * 100 + ROCBLAS_VERSION_MINOR)
#define USE_GEMM_FLAGS_FP16_ALT_IMPL (PYTORCH_ROCBLAS_VERSION_DECIMAL >= 242)
#endif

/* Level 2 */

void adjustLdLevel2(int64_t m, int64_t n, int64_t *lda)
{
  // Note: leading dimensions generally are checked that they are > 0 and at least as big the result
  // requires (even if the value won't be used).
  // TODO: why does Level3 check trans but this doesn't?
  if (n <= 1)
    *lda = std::max<int64_t>(m, 1);
}

void THCudaBlas_Sger(THCState *state, int64_t m, int64_t n, float alpha, float *x, int64_t incx, float *y, int64_t incy, float *a, int64_t lda)
{
  adjustLdLevel2(m, n, &lda);

  if( (m <= INT_MAX) && (n <= INT_MAX) && (lda <= INT_MAX)  && (incx <= INT_MAX) && (incy <= INT_MAX) )
    {
      int i_m = (int)m;
      int i_n = (int)n;
      int i_lda = (int)lda;
      int i_incx = (int)incx;
      int i_incy = (int)incy;

      cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
      THCublasCheck(cublasSger(handle, i_m, i_n, &alpha, x, i_incx, y, i_incy, a, i_lda));
      return;
    }
  THError("Cublas_Sger only supports m, n, lda, incx, incy"
          "with the bound [val] <= %d", INT_MAX);
}

void THCudaBlas_Dger(THCState *state, int64_t m, int64_t n, double alpha, double *x, int64_t incx, double *y, int64_t incy, double *a, int64_t lda)
{
  adjustLdLevel2(m, n, &lda);

  if( (m <= INT_MAX) && (n <= INT_MAX) && (lda <= INT_MAX)  && (incx <= INT_MAX) && (incy <= INT_MAX) )
    {
      int i_m = (int)m;
      int i_n = (int)n;
      int i_lda = (int)lda;
      int i_incx = (int)incx;
      int i_incy = (int)incy;

      cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
      THCublasCheck(cublasDger(handle, i_m, i_n, &alpha, x, i_incx, y, i_incy, a, i_lda));
      return;
    }
  THError("Cublas_Dger only supports m, n, lda, incx, incy"
          "with the bound [val] <= %d", INT_MAX);
}


cublasOperation_t convertTransToCublasOperation(char trans) {
  if (trans == 't') return CUBLAS_OP_T;
  else if (trans == 'n') return CUBLAS_OP_N;
  else if (trans == 'c') return CUBLAS_OP_C;
  else {
    THError("trans must be one of: t, n, c");
    return CUBLAS_OP_T;
  }
}

void adjustLdLevel3(char transa, char transb, int64_t m, int64_t n, int64_t k, int64_t *lda, int64_t *ldb, int64_t *ldc)
{
  int transa_ = ((transa == 't') || (transa == 'T'));
  int transb_ = ((transb == 't') || (transb == 'T'));

  // Note: leading dimensions generally are checked that they are > 0 and at least as big the result
  // requires (even if the value won't be used).
  if(n <= 1)
    *ldc = std::max<int64_t>(m, 1);

  if(transa_)
  {
    if(m <= 1)
      *lda = std::max<int64_t>(k, 1);
  }
  else
  {
    if(k <= 1)
      *lda = std::max<int64_t>(m, 1);
  }

  if(transb_)
  {
    if(k <= 1)
      *ldb = std::max<int64_t>(n, 1);
  }
  else
  {
    if(n <= 1)
      *ldb = std::max<int64_t>(k, 1);
  }

}

/* Level 3 */
void THCudaBlas_Sgemm(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k, float alpha, float *a, int64_t lda, float *b, int64_t ldb, float beta, float *c, int64_t ldc)
{
  at::cuda::blas::gemm<float>(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc);
}

// In CUDA 8.0, definition of data types for sgemmex changed
#if CUDA_VERSION < 8000
#  define CUDA_R_16F CUBLAS_DATA_HALF
#endif

void THCudaBlas_Hgemm(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k, at::Half alpha, at::Half *a, int64_t lda, at::Half *b, int64_t ldb, at::Half beta, at::Half *c, int64_t ldc)
{
  at::cuda::blas::gemm<at::Half>(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc);
}

void THCudaBlas_Bgemm(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k, at::BFloat16 alpha, at::BFloat16 *a, int64_t lda, at::BFloat16 *b, int64_t ldb, at::BFloat16 beta, at::BFloat16 *c, int64_t ldc)
{
  at::cuda::blas::gemm<at::BFloat16>(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc);
}

void THCudaBlas_Dgemm(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k, double alpha, double *a, int64_t lda, double *b, int64_t ldb, double beta, double *c, int64_t ldc)
{
  at::cuda::blas::gemm<double>(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc);
}

#ifndef __HIP_PLATFORM_HCC__
#if defined(CUDA_VERSION) && CUDA_VERSION >= 11200
#define cublasGemmStridedBatchedExFix cublasGemmStridedBatchedEx
#else
// Workaround for https://github.com/pytorch/pytorch/issues/45724
cublasStatus_t cublasGemmStridedBatchedExFix(cublasHandle_t &handle,
  cublasOperation_t transa,
  cublasOperation_t transb,
  int m,
  int n,
  int k,
  const void    *alpha,
  const void     *A,
  cudaDataType Atype,
  int lda,
  long long int strideA,
  const void     *B,
  cudaDataType Btype,
  int ldb,
  long long int strideB,
  const void    *beta,
  void           *C,
  cudaDataType Ctype,
  int ldc,
  long long int strideC,
  int64_t batchCount,
  cudaDataType computeType,
  cublasGemmAlgo_t algo)
{
  cudaDeviceProp* prop = at::cuda::getCurrentDeviceProperties();
  if (prop->major != 7) {
    return cublasGemmStridedBatchedEx(handle, transa, transb, m, n, k, alpha, A, Atype, lda, strideA, B, Btype, ldb, strideB, beta, C, Ctype, ldc, strideC, batchCount, computeType, algo);
  }
  cublasStatus_t result;
  constexpr int64_t split = 63 * 1024;
  for(int64_t i = 0; i < batchCount; i += split) {
    int64_t count = std::min<int64_t>(split, batchCount - i);
    result = cublasGemmStridedBatchedEx(handle, transa, transb, m, n, k, alpha,
      (char *)A + i * strideA * 2, Atype, lda, strideA,
      (char *)B + i * strideB * 2, Btype, ldb, strideB,
      beta,
      (char *)C + i * strideC * 2, Ctype, ldc, strideC,
      (int)count, computeType, algo);
    THCublasCheck(result);
  }
  return result;
}
#endif
#endif

void THCudaBlas_HgemmStridedBatched(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k,
                             at::Half alpha, const at::Half *a, int64_t lda, int64_t strideA, const at::Half *b, int64_t ldb, int64_t strideB,
                             at::Half beta, at::Half *c, int64_t ldc, int64_t strideC, int64_t batchCount)
{
  // See Note [Writing Nondeterministic Operations]
  at::globalContext().alertCuBLASConfigNotDeterministic();
  if( (m >= INT_MAX) || (n >= INT_MAX) || (k >= INT_MAX) || (lda >= INT_MAX)  || (ldb >= INT_MAX) || (ldc >= INT_MAX) || (batchCount >= INT_MAX) )

  {
    THError("Cublas_SgemmStridedBatched only supports m, n, k, lda, ldb, ldc, batchCount"
            "with the bound [val] <= %d", INT_MAX);
  }

  adjustLdLevel3(transa, transb, m, n, k, &lda, &ldb, &ldc);
  cublasOperation_t opa = convertTransToCublasOperation(transa);
  cublasOperation_t opb = convertTransToCublasOperation(transb);

  cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
  float fAlpha = alpha;
  float fBeta = beta;
#ifdef __HIP_PLATFORM_HCC__
  int flag = 0;
#if USE_GEMM_FLAGS_FP16_ALT_IMPL
  flag = at::BackwardPassGuard::is_backward_pass() ? rocblas_gemm_flags_fp16_alt_impl : 0;
#endif
  THCublasCheck(rocblas_gemm_strided_batched_ex(handle, opa, opb, (int)m, (int)n, (int)k,
                                   (void*)&fAlpha, a, rocblas_datatype_f16_r, (int)lda, strideA,
                                   b, rocblas_datatype_f16_r, (int)ldb, strideB,
                                   (void*)&fBeta, c, rocblas_datatype_f16_r, (int)ldc, strideC,
                                   c, rocblas_datatype_f16_r, (int)ldc, strideC,
                                   (int) batchCount, rocblas_datatype_f32_r, rocblas_gemm_algo_standard,
                                   0, flag));
#else
#if defined(CUDA_VERSION) && CUDA_VERSION < 11000
  // On CUDA versions prior to 11, users are required to set the math mode to CUBLAS_TENSOR_OP_MATH
  // manually to be able to use tensor cores for FP16. On CUDA 11, this is no longer required.
  THCublasCheck(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));
#endif  // CUDA_VERSION < 11000 
  THCublasCheck(cublasGemmStridedBatchedExFix(handle,
                                   opa, opb, (int)m, (int)n, (int)k,
                                   (void*)&fAlpha, a, CUDA_R_16F, (int)lda, strideA,
                                   b, CUDA_R_16F, (int)ldb, strideB,
                                   (void*)&fBeta, c, CUDA_R_16F, (int)ldc, strideC,
                                   (int)batchCount, CUDA_R_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
#if defined(CUDA_VERSION) && CUDA_VERSION < 11000
  // On CUDA versions prior to 11, users are required to set the math mode to CUBLAS_TENSOR_OP_MATH
  // manually to be able to use tensor cores for FP16. On CUDA 11, this is no longer required.
  THCublasCheck(cublasSetMathMode(handle, CUBLAS_DEFAULT_MATH));
#endif  // CUDA_VERSION < 11000
#endif // __HIP_PLATFORM_HCC__
}

void THCudaBlas_BgemmStridedBatched(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k,
                             at::BFloat16 alpha, const at::BFloat16 *a, int64_t lda, int64_t strideA, const at::BFloat16 *b, int64_t ldb, int64_t strideB,
                             at::BFloat16 beta, at::BFloat16 *c, int64_t ldc, int64_t strideC, int64_t batchCount)
{
  at::globalContext().alertCuBLASConfigNotDeterministic();
  if( (m >= INT_MAX) || (n >= INT_MAX) || (k >= INT_MAX) || (lda >= INT_MAX)  || (ldb >= INT_MAX) || (ldc >= INT_MAX) || (batchCount >= INT_MAX) )

  {
    THError("Cublas_SgemmStridedBatched only supports m, n, k, lda, ldb, ldc, batchCount"
            "with the bound [val] <= %d", INT_MAX);
  }


  adjustLdLevel3(transa, transb, m, n, k, &lda, &ldb, &ldc);
  cublasOperation_t opa = convertTransToCublasOperation(transa);
  cublasOperation_t opb = convertTransToCublasOperation(transb);

  cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
  float fAlpha = alpha;
  float fBeta = beta;

#if defined(CUDA_VERSION) && CUDA_VERSION >= 11000
  cudaDeviceProp* prop = at::cuda::getCurrentDeviceProperties();
  if (prop->major < 8) {
    TORCH_CHECK(false, "BFloat16 gemm in CUDA requires Ampere or later GPU");
  }
  THCublasCheck(cublasGemmStridedBatchedExFix(handle,
                                   opa, opb, (int)m, (int)n, (int)k,
                                   (void*)&fAlpha, a, CUDA_R_16BF, (int)lda, strideA,
                                   b, CUDA_R_16BF, (int)ldb, strideB,
                                   (void*)&fBeta, c, CUDA_R_16BF, (int)ldc, strideC,
                                   (int)batchCount, CUDA_R_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
#elif defined(__HIP_PLATFORM_HCC__)
  THCublasCheck(rocblas_gemm_strided_batched_ex(handle, opa, opb, (int)m, (int)n, (int)k,
                                  (void*)&fAlpha, a, rocblas_datatype_bf16_r, (int)lda, strideA,
                                  b, rocblas_datatype_bf16_r, (int)ldb, strideB,
                                  (void*)&fBeta, c, rocblas_datatype_bf16_r, (int)ldc, strideC,
                                  c, rocblas_datatype_bf16_r, (int)ldc, strideC,
                                  (int) batchCount, rocblas_datatype_f32_r, rocblas_gemm_algo_standard,
                                  0, 0, NULL, NULL));
#else
  TORCH_CHECK(false, "THCudaBlas_BgemmStridedBatched is only available on CUDA_VERSION >= 11");
#endif // defined(CUDA_VERSION) && CUDA_VERSION >= 11000
}

void THCudaBlas_SgemmBatched(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k,
                             float alpha, const float *a[], int64_t lda, const float *b[], int64_t ldb,
                             float beta, float *c[], int64_t ldc, int64_t batchCount)
{
  // See Note [Writing Nondeterministic Operations]
  at::globalContext().alertCuBLASConfigNotDeterministic();
  if( (m >= INT_MAX) || (n >= INT_MAX) || (k >= INT_MAX) || (lda >= INT_MAX)  || (ldb >= INT_MAX) || (ldc >= INT_MAX) || (batchCount >= INT_MAX) )
  {
    THError("Cublas_SgemmBatched only supports m, n, k, lda, ldb, ldc, batchCount"
            "with the bound [val] <= %d", INT_MAX);
  }

#ifdef __HIP_PLATFORM_HCC__

  const int64_t stridea = (transa == 'N' || transa == 'n') ? lda*k : lda*n;
  const int64_t strideb = (transb == 'N' || transb == 'n') ? ldb*n : ldb*k;
  const int64_t stridec = ldc*n;

  THCudaBlas_SgemmStridedBatched(state, transa, transb, m, n, k, alpha, *a, lda, stridea, *b, ldb, strideb, beta, *c, ldc, stridec, batchCount);

#else

  adjustLdLevel3(transa, transb, m, n, k, &lda, &ldb, &ldc);
  cublasOperation_t opa = convertTransToCublasOperation(transa);
  cublasOperation_t opb = convertTransToCublasOperation(transb);

  cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
  THCublasCheck(cublasSgemmBatched(handle,
                                   opa, opb, (int)m, (int)n, (int)k,
                                   &alpha, a, (int)lda, b, (int)ldb, &beta, c, (int)ldc,
                                   (int)batchCount));
#endif
}

void THCudaBlas_SgemmStridedBatched(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k,
                             float alpha, const float *a, int64_t lda, int64_t strideA, const float *b, int64_t ldb, int64_t strideB,
                             float beta, float *c, int64_t ldc, int64_t strideC, int64_t batchCount)
{
  // See Note [Writing Nondeterministic Operations]
  at::globalContext().alertCuBLASConfigNotDeterministic();
  if( (m >= INT_MAX) || (n >= INT_MAX) || (k >= INT_MAX) || (lda >= INT_MAX)  || (ldb >= INT_MAX) || (ldc >= INT_MAX) || (batchCount >= INT_MAX) )

  {
    THError("Cublas_SgemmStridedBatched only supports m, n, k, lda, ldb, ldc, batchCount"
            "with the bound [val] <= %d", INT_MAX);
  }

  adjustLdLevel3(transa, transb, m, n, k, &lda, &ldb, &ldc);
  cublasOperation_t opa = convertTransToCublasOperation(transa);
  cublasOperation_t opb = convertTransToCublasOperation(transb);

  cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
  THCublasCheck(cublasSgemmStridedBatched(handle,
                                   opa, opb, (int)m, (int)n, (int)k,
                                   &alpha, a, (int)lda, strideA, b, (int)ldb, strideB, &beta, c, (int)ldc, strideC,
                                   (int)batchCount));
}

void THCudaBlas_DgemmBatched(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k,
                             double alpha, const double *a[], int64_t lda, const double *b[], int64_t ldb,
                             double beta, double *c[], int64_t ldc, int64_t batchCount)
{
  // See Note [Writing Nondeterministic Operations]
  at::globalContext().alertCuBLASConfigNotDeterministic();
  if( (m >= INT_MAX) || (n >= INT_MAX) || (k >= INT_MAX) || (lda >= INT_MAX)  || (ldb >= INT_MAX) || (ldc >= INT_MAX) || (batchCount >= INT_MAX) )
  {
    THError("Cublas_DgemmBatched only supports m, n, k, lda, ldb, ldc, batchCount"
            "with the bound [val] <= %d", INT_MAX);
  }

#ifdef __HIP_PLATFORM_HCC__

  const int64_t stridea = (transa == 'N' || transa == 'n') ? lda*k : lda*n;
  const int64_t strideb = (transb == 'N' || transb == 'n') ? ldb*n : ldb*k;
  const int64_t stridec = ldc*n;

  THCudaBlas_DgemmStridedBatched(state, transa, transb, m, n, k, alpha, *a, lda, stridea, *b, ldb, strideb, beta, *c, ldc, stridec, batchCount);

#else

  adjustLdLevel3(transa, transb, m, n, k, &lda, &ldb, &ldc);
  cublasOperation_t opa = convertTransToCublasOperation(transa);
  cublasOperation_t opb = convertTransToCublasOperation(transb);

  cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
  THCublasCheck(cublasDgemmBatched(handle,
                                   opa, opb, (int)m, (int)n, (int)k,
                                   &alpha, a, (int)lda, b, (int)ldb, &beta, c, (int)ldc,
                                   (int)batchCount));
#endif
}

void THCudaBlas_DgemmStridedBatched(THCState *state, char transa, char transb, int64_t m, int64_t n, int64_t k,
                             double alpha, const double *a, int64_t lda, int64_t strideA, const double *b, int64_t ldb, int64_t strideB,
                             double beta, double *c, int64_t ldc, int64_t strideC, int64_t batchCount)
{
  // See Note [Writing Nondeterministic Operations]
  at::globalContext().alertCuBLASConfigNotDeterministic();
  if( (m >= INT_MAX) || (n >= INT_MAX) || (k >= INT_MAX) || (lda >= INT_MAX)  || (ldb >= INT_MAX) || (ldc >= INT_MAX) || (batchCount >= INT_MAX) )
  {
    THError("Cublas_DgemmBatched only supports m, n, k, lda, ldb, ldc, batchCount"
            "with the bound [val] <= %d", INT_MAX);
  }

  adjustLdLevel3(transa, transb, m, n, k, &lda, &ldb, &ldc);
  cublasOperation_t opa = convertTransToCublasOperation(transa);
  cublasOperation_t opb = convertTransToCublasOperation(transb);

  cublasHandle_t handle = at::cuda::getCurrentCUDABlasHandle();
  THCublasCheck(cublasDgemmStridedBatched(handle,
                                   opa, opb, (int)m, (int)n, (int)k,
                                   &alpha, a, (int)lda, strideA, b, (int)ldb, strideB, &beta, c, (int)ldc, strideC,
                                   (int)batchCount));
}
