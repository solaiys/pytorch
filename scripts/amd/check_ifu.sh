export PYTORCH_ROCM_ARCH=gfx908
IFU_BRANCH=IFU-master-2022-02-08

# clean up
pip uninstall -y torch apex torchvision

# pytorch
cd /var/lib/jenkins && rm -rf pytorch
git clone https://github.com/ROCmSoftwarePlatform/pytorch
cd /var/lib/jenkins/pytorch
git checkout $IFU_BRANCH
git submodule sync
git submodule update --init --recursive
PYTORCH_COMMIT=$(git rev-parse HEAD)
echo "Pytorch commit: $PYTORCH_COMMIT"
bash .jenkins/pytorch/build.sh 2>&1 |& tee build_log_${IFU_BRANCH}.txt

# apex
cd /var/lib/jenkins && rm -rf apex
git clone --recursive https://github.com/ROCmSoftwarePlatform/apex
cd /var/lib/jenkins/apex
APEX_COMMIT=$(git rev-parse HEAD)
echo "Apex commit: $APEX_COMMIT"
python setup.py install --cuda_ext --cpp_ext
cd /var/lib/jenkins/apex/tests/L0/ && bash run_rocm.sh 2>&1 |& tee /var/lib/jenkins/apex/test_apex_${IFU_BRANCH}.txt
cd /var/lib/jenkins/apex/tests/distributed/ && bash run_rocm_distributed.sh 2>&1 |& tee -a /var/lib/jenkins/apex/test_apex_${IFU_BRANCH}.txt
cd /var/lib/jenkins/apex/apex/contrib/test && python run_rocm_extensions.py 2>&1 |& tee -a /var/lib/jenkins/apex/test_apex_${IFU_BRANCH}.txt

# torch vision
cd /var/lib/jenkins && rm -rf vision
git clone https://github.com/pytorch/vision.git
cd /var/lib/jenkins/vision
TORCHVISION_COMMIT=$(git rev-parse HEAD)
echo "Torch Vision commit: $TORCHVISION_COMMIT"
conda install jpeg
python3 setup.py install
pytest test/test_transforms.py |& tee test_vision_${IFU_BRANCH}.txt
# pytest test/ -v |& tee test_vision_full_${IFU_BRANCH}.txt
