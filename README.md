﻿
# Non-Parametric Shrinkage (NPS)
NPS is a non-parametric polygenic risk prediction algorithm described in Chun et al. (2018) [(preprint)](https://www.biorxiv.org/content/early/2018/07/16/370064). NPS starts with a set of summary statistics in the form of SNP effect sizes from a large GWAS cohort. It then removes the correlation structure across summary statistics arising due to linkage disequilibrium and applies a piecewise linear interpolation on conditional mean effects. The conditional mean effects are estimated by partitioning-based non-parametric shrinkage algorithm using a training cohort with individual-level genotype data. 

For citation: 
> Chun et al. Non-parametric polygenic risk prediction using partitioned GWAS summary statistics. 
> BioRxiv 370064, doi: https://doi.org/10.1101/370064 (preprint).

For inquiries on software, please contact: 
* Sung Chun (sgchun@bwh.harvard.edu)
* Nathan Stitziel (nstitziel@wustl.edu) 
* Shamil Sunyaev (ssunyaev@rics.bwh.harvard.edu). 

## How to Install
1. Download and unpack NPS package as below. Some of NPS codes are optimized in C++ and need to be compiled with GNU C++ compiler (GCC-4.4 or later). This will create two executable binaries, **stdgt** and **grs**, in the top-level NPS directory. **stdgt** is used to convert allelic dosages to standardized genotypes with the mean of 0 and variance of 1. **grs** calculates genetic risk scores using per-SNP genetic effects computed by NPS.

   ```bash
   tar -zxvf nps-1.0.0.tar.gz
   cd nps-1.0.0/
   make
   ```

   **Note on computer clusters: If you need to load a GCC module to compile NPS, you have to do the same in job scripts `nps_stdgt.job` and `nps_score.job`. stdgt and grs will depend on GCC shared libraries in the run time.**

2. The core NPS module was implemented in R and requires R-3.3 or later (available for download at [https://www.r-project.org/](https://www.r-project.org/)). Although NPS can run on a standard version of R, we strongly recommend to use R linked with a linear algebra acceleration library, such as [OpenBLAS](https://www.openblas.net/), [Intel Math Kernel Library (MKL)](https://software.intel.com/en-us/articles/using-intel-mkl-with-r) or [Microsoft R open](https://mran.microsoft.com/open). These libraries can substantially speed up NPS operations.  

3. (*Optional*) NPS relies on R modules, [pROC](https://cran.r-project.org/web/packages/pROC/index.html) and [DescTools](https://cran.r-project.org/web/packages/DescTools/index.html), to calculate the AUC and Nagelkerke's R^2 statistics. These modules are optional; if they are not installed, AUC and Nagelkerke's R^2 will simply not be reported. To enable this feature, please install these packages by running the following on command line: 

   ```bash
   Rscript -e 'install.packages("pROC", repos="http://cran.r-project.org")' 
   Rscript -e 'install.packages("DescTools", repos="http://cran.r-project.org")' 
   ```

   If you need to install the R extensions in the home directory (e.g. ~/R), please do the following instead:

   ```bash
   Rscript -e 'install.packages("pROC", "~/R", repos="http://cran.r-project.org")' 
   Rscript -e 'install.packages("DescTools", "~/R", repos="http://cran.r-project.org")' 
   
   # Add "~/R" to the local R library path in your login shell's start-up file.
   # For example, in case of bash, add the following to .bash_profile or .bashrc: 
   export R_LIBS="~/R:$R_LIBS"
   ```

4. Although we provide a command line tool to run NPS on desktop computers [without parallelization](https://github.com/sgchun/nps#running-nps-on-test-set-1-without-parallelization), we strongly recommend to run it on computer clusters processing all chromosomes in parallel. To make this easier, we provide job scripts for [SGE](https://github.com/sgchun/nps#running-nps-on-test-set-1-using-sge-clusters) and [LSF](https://github.com/sgchun/nps#running-nps-on-test-set-1-using-lsf-clusters) clusters in [sge/](https://github.com/sgchun/nps/tree/master/sge) and [lsf/](https://github.com/sgchun/nps/tree/master/lsf) directories. You may still need to modify the provided job scripts to load necessary modules similarly in the following example of [sge/nps_score.job](https://github.com/sgchun/nps/blob/master/sge/nps_score.job):

   ```bash
   ###
   # ADD CODES TO LOAD MODULES HERE
   #
   # Load R module if necessary. 
   # 
   # If you loaded a GCC module to compile grs, you also need to load 
   # the GCC module here. 
   #
   # ---------------------- EXAMPLE ----------------------------
   # On clusters running environment modules and providing R-mkl
   module add gcc/5.3.0 
   module add R-mkl/3.3.2
   
   # On clusters running DotKit instead and supporting OpenblasR
   use GCC-5.3.0 
   use OpenblasR
   # -----------------------------------------------------------
   ...
   ```

   **Note: Do not blindly use the above lines. The details will depend on specific system configurations.** 

5. We provide job scripts to prepare training and validation cohorts for NPS. These scripts require [bgen](https://bitbucket.org/gavinband/bgen/wiki/bgenix) and [qctool v2](https://www.well.ox.ac.uk/~gav/qctool/). You will need to either install these packages or edit the job scripts (`support/*.job`) to load as modules. 

## Input files for NPS
To run NPS, you need the following set of input files: 

1. **GWAS summary statistics.** NPS supports two summary statistics formats: *MINIMAL* and *PREFORMATTED*. Internally, NPS uses PREFORMATTED summary statistics. With real data, however, we generally recommend to prepare summary statistics in the MINIMAL format and harmonize them with training genotype data using provided NPS scripts. This will automatically convert the summary statistics file into the PREFORMATTED format ([step-by-step instruction](https://github.com/sgchun/nps#how-to-prepare-training-and-validation-cohorts-for-nps)). 
   - The MINIMAL format is a tab-delimited text file with the following seven or eight columns: 
     - **chr**: chromosome number. NPS expects only chromosomes 1-22.
     - **pos**: base position of SNP.
     - **a1** and **a2**: alleles at each SNP in any order.
     - **effal**: effect allele. It should match either a1 or a2 allele. 
     - **pval**: p-value of association. 
     - **effbeta**: estimated *per-allele* effect size of *the effect allele*. For case/control GWAS, log(OR) should be used. *DO NOT pre-convert them to effect sizes relative to standardized genotypes. NPS will handle this automatically.*
     - **effaf**: (*Optional*) allele frequency of *the effect allele* in the discovery GWAS cohort. If this column is missing, NPS will use the allele frequencies of training cohort instead. Although this is optional, we **strongly recommend to include effaf when available in GWAS summary statistics.** When this column is provided, NPS can apply an extra QC check to cross-check the effect allele frequency between GWAS and training cohort data. 
     ```
     chr	pos	a1	a2	effal	pval	effbeta	effaf
     1	569406	G	A	G	0.8494	0.05191	0.99858
     1	751756	C	T	C	0.6996	0.00546	0.14418
     1	753405	C	A	C	0.8189	0.00316	0.17332
     1	753541	A	G	A	0.8945	0.00184	0.16054
     1	754182	A	G	A	0.7920	0.00361	0.18067
     1	754192	A	G	A	0.7853	0.00373	0.1809
     1	754334	T	C	T	0.7179	0.00500	0.18554
     1	755890	A	T	A	0.7516	0.00441	0.17327
     1	756604	A	G	A	0.9064	0.00162	0.18202
     ...
     ```
     
   - The *PREFORMATTED* format is the native format for NPS. We provide summary statistics of [our test cases](https://github.com/sgchun/nps#test-cases) in this format so that NPS can run on them directly without conversion. This is a tab-delimited text file format, and rows must be sorted by chromosome numbers and positions of SNPs. The following seven columns are required: 
     - **chr**: chromosome name starting with "chr." NPS expects only chromosomes chr1-chr22.
     - **pos**: base position of SNP.
     - **ref** and **alt**: reference and alternative alleles of SNP. 
     - **reffreq**: allele frequency of reference allele in the discovery GWAS cohort. 
     - **pval**: p-value of association. 
     - **effalt**: estimated *per-allele* effect size of *the alternative allele*. For case/control GWAS, log(OR) should be used. NPS will convert **effalt** to effect sizes relative to *the standardized genotype* internally using **reffreq**.  
     ```
     chr	pos	ref	alt	reffreq	pval	effalt
     chr1	676118	G	A	0.91584	0.7908	0.0012
     chr1	734349	G	A	0.90222	0.6989	0.001636
     chr1	770886	G	A	0.91708	0.721	0.001627
     chr1	785050	G	A	0.1139	0.3353	-0.00381
     chr1	798400	G	A	0.8032	0.03301	0.006736
     chr1	804759	G	A	0.8837	0.7324	-0.00134
     chr1	831489	G	A	0.2797	0.1287	0.004252
     chr1	832318	G	A	0.2797	0.4102	0.002304
     chr1	836924	G	A	0.7958	0.6591	-0.001374
     ...
     ```
     With this format, NPS will not run automatic data harmonization procedures. The user need to ensure that the summary statistics file does not include InDels, tri-allelic SNPs or duplicated markers and that all SNPs of training genotypes files have non-missing summary statistics. If these requirements are violated, NPS will report an error and terminate. 

2. **Training genotypes in the qctool dosage format.** NPS supports the dosage format for the genotype data of training cohort. We use [qctool](https://www.well.ox.ac.uk/~gav/qctool/) to generate these files (See [instructions](https://github.com/sgchun/nps#how-to-prepare-training-and-validation-cohorts-for-nps)). The genotype files need to be split by chromosomes for parallelization, and for each chromosome, the file should be named as "chrom*N*.*DatasetTag*.dosage.gz." These files are space-delimited compressed text files with the first six columns providing the marker information and rest of columns specifying the allelic dosage of that marker in each individual:

   ```
   chromosome SNPID rsid position alleleA alleleB trainI2 trainI3 trainI39 trainI41 trainI58
   01 1_676118:676118:G:A 1_676118:676118:G:A 676118 G A 0 0 0 0 0
   01 1_734349:734349:G:A 1_734349:734349:G:A 734349 G A 1 0 0 0 0
   01 1_770886:770886:G:A 1_770886:770886:G:A 770886 G A 0 0 0 1 0
   01 1_785050:785050:G:A 1_785050:785050:G:A 785050 G A 1 2 2 2 2
   01 1_798400:798400:G:A 1_798400:798400:G:A 798400 G A 1 0 1 1 0
   01 1_804759:804759:G:A 1_804759:804759:G:A 804759 G A 1 0 1 0 0
   01 1_831489:831489:G:A 1_831489:831489:G:A 831489 G A 1 2 2 1 2
   01 1_832318:832318:G:A 1_832318:832318:G:A 832318 G A 1 2 2 1 2
   01 1_836924:836924:G:A 1_836924:836924:G:A 836924 G A 0 0 0 0 0
   ...
   ```
   
   To match SNPs between GWAS summary statistics and training and validation cohorts, NPS relies on the combination of chromosome, base position and alleles. All alleles are designated on the forward strand (+). **SNPID** or **rsid** will not be used. The **alleleA** has to match **ref** allele, and the **alleleB** has to match **alt** allele in the GWAS summary statistics. The allelic dosage counts the genetic dosage of **alleleB** in each individual. Markers are expected to be in the order of **position**. 

3. **Training sample IDs in PLINK .fam format.** The samples in the .fam file should appear in the exactly same order as the samples in the training genotype files. This is *space-separated* six-column text file without a header. The phenotype information in this file will be ignored. See [here](https://www.cog-genomics.org/plink2/formats#fam) for the details on the format. 
   ```
   trainF2 trainI2 0 0 0 -9
   trainF3 trainI3 0 0 0 -9
   trainF39 trainI39 0 0 0 -9
   trainF41 trainI41 0 0 0 -9
   trainF58 trainI58 0 0 0 -9
   ```
4. **Training phenotypes in PLINK phenotype format.** NPS looks up phenotypes in a separately prepared phenotype file. The phenotype name has to be **Outcome** with cases and controls encoded by **1** and **0**, respectively. **FID** and **IID** are used together to match samples to .fam file. This file is *tab-delimited*, and samples can appear in any order. Missing phenotypes (e.g. encoded with **-9** or missing entry of samples described in .fam file) are not allowed.
   ```
   FID   IID    Outcome
   trainF2  trainI2  0
   trainF39 trainI39 0
   trainF3  trainI3  1
   trainF41 trainI41 1
   trainF58 trainI58 0
   ```
5. **Validation genotypes in qctool dosage format.** Same as the training genotype dosage format. 
6. **Validation sample IDs in PLINK .fam format.** Same as the training sample ID file format.
7. **Validation phenotypes in PLINK phenotype format.** Similar to the training phenotype file format. Unlike the training cohort phenotype file, missing phenotypes (encoded by **-9**) are allowed in a validation cohort phenotype file. Samples with missing phenotypes will be simply excluded when evaluating the accuracy of prediction model.

## Running NPS 

### Test cases
We provide two sets of simulated test cases. Due to their large file sizes, they are provided separately from the software distribution. Please download them from Sunyaev Lab server (ftp://genetics.bwh.harvard.edu/download/schun/). Test set #1 is relatively small (225MB), and NPS can complete in less than 1 hour in total on a modest desktop PC even without linear-algebra acceleration. In contrast, test set #2 is more realistic simulation (11GB) and will require serious computational resources. NPS will generate up to 1 TB of intermediary data and can take 1/2 day to a day on computer clusters with linear-algebra acceleration.

Both simulation datasets were generated using our multivariate-normal simulator (See our NPS manuscript for the details). Briefly:    
- **Test set #1.** The number of markers across the genome is limited to 100,449. We assume that all causal SNPs are included in the 100,449 SNPs. Note that this is unrealistic assumption; causal SNPs cannot be accurately tagged with such a sparse SNP set. The fraction of causal SNP is 0.005 (a total of 522 causal SNPs). The GWAS cohort size is 100,000. The training cohort has 2,500 cases and 2,500 controls. The validation cohort consists of 5,000 individuals without case over-sampling. The heritability is 0.5. The phenotype prevalence is 5%.  

- **Test set #2.** The number of markers across the genome is 5,012,500. The fraction of causal SNP is 0.001 (a total of 5,008 causal SNPs). The GWAS cohort size is 100,000. The training cohort has 2,500 cases and 2,500 controls. The validation cohort consists of 5,000 samples without case over-sampling. The heritability is 0.5. The phenotype prevalence is 5%. This is one of the benchmark simulation datasets used in our manuscript, with 10-fold reduced validation cohort size. 

We assume that the test datasets will be downloaded and unpacked in the following directories: 
```bash
$ cd nps-1.0.0/testdata/
$ tar -zxvf NPS.Test1.tar.gz 
# This will create the following test data files in nps-1.0.0/testdata/Test1
# Test1/Test1.summstats.txt (PREFORMATTED GWAS summary statistics)
# Test1/chrom1.Test1.train.dosage.gz (training cohort genotypes)
# Test1/chrom2.Test1.train.dosage.gz (training cohort genotypes)
# ... 
# Test1/Test1.train.2.5K_2.5K.fam (training cohort sample IDs)
# Test1/Test1.train.2.5K_2.5K.phen (training cohort phenotypes)
# Test1/chrom1.Test1.val.dosage.gz (validation cohort genotypes)
# Test1/chrom2.Test1.val.dosage.gz (validation cohort genotypes)
# ... 
# Test1/Test1.val.5K.fam (validation cohort sample IDs)
# Test1/Test1.val.5K.phen (validation cohort phenotypes)

$ tar -zxvf NPS.Test2.tar.gz 
# This will create the following test data in nps-1.0.0/testdata/Test2
# Test2/Test2.summstats.txt (PREFORMATTED GWAS summary statistics)
# Test2/chrom1.Test2.train.dosage.gz (training cohort genotypes)
# Test2/chrom2.Test2.train.dosage.gz (training cohort genotypes)
# ... 
# Test2/Test2.train.2.5K_2.5K.fam (training cohort sample IDs)
# Test2/Test2.train.2.5K_2.5K.phen (training cohort phenotypes)
# Test2/chrom1.Test2.val.dosage.gz (validation cohort genotypes)
# Test2/chrom2.Test2.val.dosage.gz (validation cohort genotypes)
# ... 
# Test2/Test2.val.5K.fam (validation cohort sample IDs)
# Test2/Test2.val.5K.phen (validation cohort phenotypes)
```

### Running NPS on Test set #1 without parallelization
Test set #1 is a small dataset and can be easily tested on modest desktop computers. For instructions on running it on computer clusters, see [SGE](https://github.com/sgchun/nps#running-nps-on-test-set-1-using-sge-clusters) and [LSF](https://github.com/sgchun/nps#running-nps-on-test-set-1-using-lsf-clusters) sections. NPS was designed with parallel processing on clusters in mind. Therefore, the algorithm is broken down into multiple steps, and computationally-intensive steps are split by chromosomes and run in parallel. For desktop computers, we provide `run_all_chroms.sh` to run SGE job scripts sequentially processing one chromosome at a time.  

1. **Standardize genotypes.** The first step is to standardize the training genotypes to the mean of 0 and variance of 1 using `snps_stdgt.job`. The first parameter (`testdata/Test1`) is the location of training cohort data, where NPS will find chrom*N*.*DatasetTag*.dosage.gz files. The second parameter (`Test1.train`) is the *DatasetTag* of training cohort. 
   ```bash
   cd nps-1.0.0/
   
   ./run_all_chroms.sh sge/nps_stdgt.job testdata/Test1 Test1.train
   ```

   * Note: If you use [NPS support scripts](https://github.com/sgchun/nps#how-to-prepare-training-and-validation-cohorts-for-nps) to harmonize training data, *DatasetTag* will be "*CohortName*.QC2" as the genotype files will be named as chrom*N*.*CohortName*.QC2.dosage.gz.

   After all jobs are completed, `nps_check.sh` script can be used to verify that all jobs were successfully completed:
   ```bash
   ./nps_check.sh stdgt testdata/Test1 Test1.train 
   ```
   If `nps_check.sh` finds an error, `FAIL` message will be printed. If everything is fine, only `OK` messages will be reported: 
   > Verifying nps_stdgt:  
   > Checking testdata/Test1/chrom1.Test2.train ...OK  
   > Checking testdata/Test1/chrom2.Test2.train ...OK  
   > Checking testdata/Test1/chrom3.Test2.train ...OK  
   > ...  

2. **Configure an NPS run.** Next, we run `npsR/nps_init.R` to configure the NPS run: 
   ```bash
   Rscript npsR/nps_init.R testdata/Test1/Test1.summstats.txt testdata/Test1 testdata/Test1/Test1.train.2.5K_2.5K.fam testdata/Test1/Test1.train.2.5K_2.5K.phen Test1.train 80 testdata/Test1/npsdat
   ```
    The command arguments are:
    - GWAS summary statistics file in the PREFORMATTED format: `testdata/Test1/Test1.summstats.txt`
    - directory containing training genotypes: `testdata/Test1`
    - IDs of training samples: `testdata/Test1/Test1.train.2.5K_2.5K.fam`
    - phenotypes of training samples: `testdata/Test1/Test1.train.2.5K_2.5K.phen`
    - DatasetTag of training cohort genotypes: `Test1.train`
    - analysis window size: `80` SNPs. The window size of 80 SNPs for ~100,000 genome-wide SNPs is comparable to 4,000 SNPs for ~5,000,000 genome-wide SNPs. 
    - directory to store intermediate data: `testdata/Test1/npsdat`. The NPS configuration and all intermediate data will be stored here.

   The set-up can be double-checked by running: 
   `./nps_check.sh init testdata/Test1/npsdat/`

3. **Transform data to the decorrelated "eigenlocus" space.** This is one of the most time-consuming steps in NPS. The first argument to `nps_decor.job` is the NPS data directory, in this case, `testdata/Test1/npsdat/`. The second argument is the window shift. We recommend to run NPS four times on shifted windows and merge the results in the last step. For the window shift, we recommend the shifts of 0, 1/WINSZ, 2/WINSZ and 3/WINSZ SNPs, where WINSZ is the size of analysis window. For test set #1, we use the WINSZ of 80, thus window shifts should be `0`, `20`, `40` and `60`. 
   ```bash
   ./run_all_chroms.sh sge/nps_decor.job testdata/Test1/npsdat/ 0
   ./run_all_chroms.sh sge/nps_decor.job testdata/Test1/npsdat/ 20
   ./run_all_chroms.sh sge/nps_decor.job testdata/Test1/npsdat/ 40
   ./run_all_chroms.sh sge/nps_decor.job testdata/Test1/npsdat/ 60
   
   # Check the results
   ./nps_check.sh decor testdata/Test1/npsdat/ 0 20 40 60 
   ```

4. **Prune correlations across windows.** This step prunes the correlation between genotypes across adjacent windows in the eigenlocus space by running `nps_prune.job` job. The first argument is the NPS data directory (`testdata/Test1/npsdat/`) and the second argument is the window shift (`0`, `20`, `40` or `60`). 

   ```bash
   ./run_all_chroms.sh sge/nps_prune.job testdata/Test1/npsdat/ 0
   ./run_all_chroms.sh sge/nps_prune.job testdata/Test1/npsdat/ 20
   ./run_all_chroms.sh sge/nps_prune.job testdata/Test1/npsdat/ 40
   ./run_all_chroms.sh sge/nps_prune.job testdata/Test1/npsdat/ 60
   
   # Check the results
   ./nps_check.sh prune testdata/Test1/npsdat/ 0 20 40 60
   ```

5. **Separate GWAS-significant partition.** The partition of GWAS-significant associations will be separated out from the rest of association signals. The first argument is the NPS data directory (`testdata/Test1/npsdat/`) and the second argument is the window shift (`0`, `20`, `40` or `60`). 
   ```bash
   ./run_all_chroms.sh sge/nps_gwassig.job testdata/Test1/npsdat/ 0
   ./run_all_chroms.sh sge/nps_gwassig.job testdata/Test1/npsdat/ 20
   ./run_all_chroms.sh sge/nps_gwassig.job testdata/Test1/npsdat/ 40
   ./run_all_chroms.sh sge/nps_gwassig.job testdata/Test1/npsdat/ 60
   
   # Check the results
   ./nps_check.sh gwassig testdata/Test1/npsdat/ 0 20 40 60
   ```

6. **Partition the rest of data** We define the partition scheme by running `npsR/nps_prep_part.R`. The first argument is the NPS data directory (`testdata/Test1/npsdat/`) and the second argument is the window shift (`0`, `20`, `40` or `60`). The third and last arguments are the numbers of partitions to set-up. We recommend 10-by-10 double-partitioning on the intervals of eigenvalues of projection and estimated effect sizes in the eigenlocus space, therefore, last two arguments are `10` and `10`: 
   ```
   Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 0 10 10 
   Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 20 10 10 
   Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 40 10 10 
   Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 60 10 10 
   
   # Check the results
   ./nps_check.sh prep_part testdata/Test1/npsdat/ 0 20 40 60 
   ```
   
   Then, partitioned genetic risk scores will be calculated using training samples with `nps_part.job`. The first argument is the NPS data directory (`testdata/Test1/npsdat/`) and the second argument is the window shift (`0`, `20`, `40` or `60`): 
   ```
   ./run_all_chroms.sh sge/nps_part.job testdata/Test1/npsdat/ 0
   ./run_all_chroms.sh sge/nps_part.job testdata/Test1/npsdat/ 20
   ./run_all_chroms.sh sge/nps_part.job testdata/Test1/npsdat/ 40
   ./run_all_chroms.sh sge/nps_part.job testdata/Test1/npsdat/ 60
   
   # Check the results
   ./nps_check.sh part testdata/Test1/npsdat/ 0 20 40 60
   ```

7. **Estimate per-partition shrinkage weights.** We estimate the per-partition weights using `npsR/nps_weight.R`. The first argument is the NPS data directory (`testdata/Test1/npsdat/`) and the second argument is the window shift (`0`, `20`, `40` or `60`):
   ```bash
   Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 0 
   Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 20 
   Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 40 
   Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 60 
   
   # Check the results
   ./nps_check.sh weight testdata/Test1/npsdat/ 0 20 40 60
   ```
   
   We also provide two optional utilities: 
   * `npsR/nps_train_AUC.R` reports the AUC statistics of prediction in training cohort. You need **pROC** package installed to be able to run this. It will combine prediction models of all shifted windows (`0`, `20`, `40` and `60`) and report the overall performance. 
     ```bash
     Rscript npsR/nps_train_AUC.R testdata/Test1/npsdat/ 0 20 40 60
     ```
     
     With test set #1, the reported AUC is as follows: 
     > Data: 2500 controls < 2500 cases.  
     > Area under the curve: 0.8799  
     > 95% CI: 0.8707-0.8891 (DeLong)  
     
     **Note: true prediction accuracy has be measured in independent out-of-sample validation cohort.** 
   
   * `npsR/nps_plot_shrinkage.R` plots the overall curve of GWAS effect sizes re-weighted by per-partition shrinkage. The plot of NPS shrinkage curves will be saved in a pdf file specified by the second argument (`Test1.nps.pdf`) [See the plot](https://github.com/sgchun/nps/blob/master/testdata/Test1.nps.pdf). 
     ```
     Rscript npsR/nps_plot_shrinkage.R testdata/Test1/npsdat/ Test1.nps.pdf 0 20 40 60
     ```

8. **Convert back to per-SNP effect sizes.** The re-weighted effect sizes should be converted back to the original per-SNP space from the eigenlocus space. The first argument is the NPS data directory (`testdata/Test1/npsdat/`) and the second argument is the window shift (`0`, `20`, `40` or `60`): 
   ```bash
   ./run_all_chroms.sh sge/nps_back2snpeff.job testdata/Test1/npsdat/ 0
   ./run_all_chroms.sh sge/nps_back2snpeff.job testdata/Test1/npsdat/ 20
   ./run_all_chroms.sh sge/nps_back2snpeff.job testdata/Test1/npsdat/ 40
   ./run_all_chroms.sh sge/nps_back2snpeff.job testdata/Test1/npsdat/ 60
   
   # Check the results
   ./nps_check.sh back2snpeff testdata/Test1/npsdat/ 0 20 40 60
   ```
   This will generate per-SNP re-weighted effect sizes in files of "testdata/Test1/npsdat/Test1.train.adjbetahat.chrom*N*.txt" for the window shift of 0, and "testdata/Test1/npsdat/Test1.train.win_*shift*.adjbetahat.chrom*N*.txt" for the window shifts of 20, 40 and 60.

9. **Validate the accuracy of prediction model in a validation cohort.** Last, polygenic risk scores can be calculated for each chromosome and for each individuals in the validation cohort using `sge/nps_score.job` as follows: 
   ```bash
   ./run_all_chroms.sh sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 0 
   ./run_all_chroms.sh sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 20
   ./run_all_chroms.sh sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 40
   ./run_all_chroms.sh sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 60
   
   # Check the results
   ./nps_check.sh score testdata/Test1/npsdat/ testdata/Test1/ Test1.val 0 20 40 60
   ```
   Here, the first argument for `sge/nps_score.job` is the NPS data directory (`testdata/Test1/npsdat/`), the second argument is the directory containing validation cohort data (`testdata/Test1/`), and the third argument is the DatasetTag for validation genotypes. Since the genotype files for validation cohorts are named as chrom*N*.*Test1.val*.dosage.gz, DatasetTag has to be `Test1.val`. The last argument is the window shift (`0`, `20`, `40` or `60`). 
   
   Then, `npsR/nps_val.R` will combine polygenic risk scores across all shifted windows and report per-individual scores along with overall accuracy statistics: 
   ```
   Rscript npsR/nps_val.R testdata/Test1/npsdat/ testdata/Test1/ testdata/Test1/Test1.val.5K.fam testdata/Test1/Test1.val.5K.phen 0 20 40 60 
   ```
   The command arguments are: 
   - NPS data directory: `testdata/Test1/npsdat/`
   - directory containing validation genotypes: `testdata/Test1`
   - IDs of validation samples: `testdata/Test1/Test1.val.5K.fam`
   - phenotypes of validation samples: `testdata/Test1/Test1.val.5K.phen`
   - window shifts used in the prediction model: `0 20 40 60`. 
   
   `npsR/nps_val.R` print out the following output on Test case #1. Here, it reports the AUC of 0.8531 and Nagelkerke's R2 of 0.2693255. The individual NPS polygenic score is stored in the file `testdata/Test1.val.5K.phen.nps_score`. 
   > Non-Parametric Shrinkage 1.0.0   
   > Validation cohort:  
   > Total  5000 samples  
   > 271  case samples  
   > 4729  control samples  
   > 0  samples with missing phenotype (-9)  
   > Includes TotalLiability  
   > Checking a prediciton model (winshift = 0 )...  
   > Observed-scale R2 = 0.08795757   
   > Liability-scale R2 = 0.4207207   
   > Checking a prediciton model (winshift = 20 )...  
   > Observed-scale R2 = 0.08940181   
   > Liability-scale R2 = 0.4150352   
   > Checking a prediciton model (winshift = 40 )...  
   > Observed-scale R2 = 0.08912039   
   > Liability-scale R2 = 0.4187129   
   > Checking a prediciton model (winshift = 60 )...  
   > Observed-scale R2 = 0.09010319   
   > Liability-scale R2 = 0.4182834   
   >   
   >   
   >   
   > Producing a combined prediction model...OK (saved in testdata/Test1.val.5K.phen.nps_score )  
   > Observed-scale R2 = 0.09048684   
   > Liability-scale R2 = 0.4244738   
   > Loading required package: pROC  
   > Type 'citation("pROC")' for a citation.  
   >   
   > Attaching package: ‘pROC’  
   >   
   > The following objects are masked from ‘package:stats’:  
   >   
   > cov, smooth, var  
   >   
   > AUC:  
   >   
   > Call:  
   > roc.default(controls = prisk[vlY == 0], cases = prisk[vlY ==     1], ci = TRUE)  
   >   
   > Data: 4729 controls < 271 cases.  
   > Area under the curve: 0.8531  
   > 95% CI: 0.8321-0.8741 (DeLong)  
   > Loading required package: DescTools  
   > Nagelkerke's R2 = 0.2693255   
   >   
   > Call: &nbsp;glm(formula = vlY ~ prisk, family = binomial(link = "logit"))  
   >   
   > Coefficients:  
   > (Intercept) &nbsp; &nbsp; &nbsp; &nbsp;prisk    
   > &nbsp; &nbsp; -7.2563 &nbsp; &nbsp; 0.1908    
   >   
   > Degrees of Freedom: 4999 Total (i.e. Null); &nbsp;4998 Residual  
   > Null Deviance: &nbsp; &nbsp; 2107   
   > Residual Deviance: 1621 &nbsp;AIC: 1625  
   > Done  

### Running NPS on Test set #1 using SGE clusters

To run NPS on SGE clusters, please run the following steps. All steps have to be run on the top-level NPS directory (`nps-1.0.0/`) and jobs should be launched with the `qsub -cwd` option. The option `-t 1-22` will run NPS jobs over all 22 chromosomes in parallel. 

```
cd nps-1.0.0/

# Standardize genotypes
qsub -cwd -t 1-22 sge/nps_stdgt.job testdata/Test1 Test1.train

# Check the results
./nps_check.sh stdgt testdata/Test1 Test1.train 

# Configure
Rscript npsR/nps_init.R testdata/Test1/Test1.summstats.txt testdata/Test1 testdata/Test1/Test1.train.2.5K_2.5K.fam testdata/Test1/Test1.train.2.5K_2.5K.phen Test1.train 80 testdata/Test1/npsdat

# Check the results
./nps_check.sh init testdata/Test1/npsdat/

# Transform data to the decorrelate eigenlocus space
qsub -cwd -t 1-22 sge/nps_decor.job testdata/Test1/npsdat/ 0 
qsub -cwd -t 1-22 sge/nps_decor.job testdata/Test1/npsdat/ 20 
qsub -cwd -t 1-22 sge/nps_decor.job testdata/Test1/npsdat/ 40 
qsub -cwd -t 1-22 sge/nps_decor.job testdata/Test1/npsdat/ 60 

# Check the results
./nps_check.sh decor testdata/Test1/npsdat/ 0 20 40 60 

# Prune correlations across windows
qsub -cwd -t 1-22 sge/nps_prune.job testdata/Test1/npsdat/ 0
qsub -cwd -t 1-22 sge/nps_prune.job testdata/Test1/npsdat/ 20
qsub -cwd -t 1-22 sge/nps_prune.job testdata/Test1/npsdat/ 40
qsub -cwd -t 1-22 sge/nps_prune.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh prune testdata/Test1/npsdat/ 0 20 40 60

# Separate the GWAS-significant partition
qsub -cwd -t 1-22 sge/nps_gwassig.job testdata/Test1/npsdat/ 0
qsub -cwd -t 1-22 sge/nps_gwassig.job testdata/Test1/npsdat/ 20
qsub -cwd -t 1-22 sge/nps_gwassig.job testdata/Test1/npsdat/ 40
qsub -cwd -t 1-22 sge/nps_gwassig.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh gwassig testdata/Test1/npsdat/ 0 20 40 60

# Define partitioning boundaries for the rest of data
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 0 10 10 
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 20 10 10 
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 40 10 10 
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 60 10 10 

# Check the results
./nps_check.sh prep_part testdata/Test1/npsdat/ 0 20 40 60 

# Calculate partitioned risk scores in the training cohort
qsub -cwd -t 1-22 sge/nps_part.job testdata/Test1/npsdat/ 0
qsub -cwd -t 1-22 sge/nps_part.job testdata/Test1/npsdat/ 20
qsub -cwd -t 1-22 sge/nps_part.job testdata/Test1/npsdat/ 40
qsub -cwd -t 1-22 sge/nps_part.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh part testdata/Test1/npsdat/ 0 20 40 60

# Estimate per-partition shrinkage weights
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 0 
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 20 
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 40 
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 60 

# Check the results
./nps_check.sh weight testdata/Test1/npsdat/ 0 20 40 60

# (Optional) Report the overall AUC of prediction in the training cohort
Rscript npsR/nps_train_AUC.R testdata/Test1/npsdat/ 0 20 40 60
# (Optional) Generate a plot of overall shrinkage curves
Rscript npsR/nps_plot_shrinkage.R testdata/Test1/npsdat/ Test1.nps.pdf 0 20 40 60

# Convert back to per-SNP effect sizes
qsub -cwd -t 1-22 sge/nps_back2snpeff.job testdata/Test1/npsdat/ 0
qsub -cwd -t 1-22 sge/nps_back2snpeff.job testdata/Test1/npsdat/ 20
qsub -cwd -t 1-22 sge/nps_back2snpeff.job testdata/Test1/npsdat/ 40
qsub -cwd -t 1-22 sge/nps_back2snpeff.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh back2snpeff testdata/Test1/npsdat/ 0 20 40 60

# Calculate polygenic scores for each chromosome and for each individual in the validation cohort
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 0
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 20
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 40
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 60

# Check the results
./nps_check.sh score testdata/Test1/npsdat/ testdata/Test1/ Test1.val 0 20 40 60

# Calculate overall polygenic scores and report prediction accuracies
Rscript npsR/nps_val.R testdata/Test1/npsdat/ testdata/Test1/ testdata/Test1/Test1.val.5K.fam testdata/Test1/Test1.val.5K.phen 0 20 40 60 
```

### Running NPS on Test set #1 using LSF clusters

Running on LSF clusters is similar. We provide the job scripts in `lsf/` directory.

```
cd nps-1.0.0/

# Standardize genotypes
bsub -J stdgt[1-22] lsf/nps_stdgt.job testdata/Test1 Test1.train

# Check the results
./nps_check.sh stdgt testdata/Test1 Test1.train

# Configure
Rscript npsR/nps_init.R testdata/Test1/Test1.summstats.txt testdata/Test1 testdata/Test1/Test1.train.2.5K_2.5K.fam testdata/Test1/Test1.train.2.5K_2.5K.phen Test1.train 80 testdata/Test1/npsdat

# Check the results
./nps_check.sh init testdata/Test1/npsdat/

# Transform data to the decorrelate eigenlocus space
bsub -J decor[1-22] lsf/nps_decor.job testdata/Test1/npsdat/ 0
bsub -J decor[1-22] lsf/nps_decor.job testdata/Test1/npsdat/ 20
bsub -J decor[1-22] lsf/nps_decor.job testdata/Test1/npsdat/ 40
bsub -J decor[1-22] lsf/nps_decor.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh decor testdata/Test1/npsdat/ 0 20 40 60

# Prune correlations across windows
bsub -J prune[1-22] lsf/nps_prune.job testdata/Test1/npsdat/ 0
bsub -J prune[1-22] lsf/nps_prune.job testdata/Test1/npsdat/ 20
bsub -J prune[1-22] lsf/nps_prune.job testdata/Test1/npsdat/ 40
bsub -J prune[1-22] lsf/nps_prune.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh prune testdata/Test1/npsdat/ 0 20 40 60

# Separate the GWAS-significant partition
bsub -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test1/npsdat/ 0
bsub -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test1/npsdat/ 20
bsub -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test1/npsdat/ 40
bsub -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh gwassig testdata/Test1/npsdat/ 0 20 40 60

# Define partitioning boundaries for the rest of data
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 0 10 10
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 20 10 10
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 40 10 10
Rscript npsR/nps_prep_part.R testdata/Test1/npsdat/ 60 10 10

# Check the results
./nps_check.sh prep_part testdata/Test1/npsdat/ 0 20 40 60

# Calculate partitioned risk scores in the training cohort
bsub -J part[1-22] lsf/nps_part.job testdata/Test1/npsdat/ 0
bsub -J part[1-22] lsf/nps_part.job testdata/Test1/npsdat/ 20
bsub -J part[1-22] lsf/nps_part.job testdata/Test1/npsdat/ 40
bsub -J part[1-22] lsf/nps_part.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh part testdata/Test1/npsdat/ 0 20 40 60

# Estimate per-partition shrinkage weights
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 0
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 20
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 40
Rscript npsR/nps_weight.R testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh weight testdata/Test1/npsdat/ 0 20 40 60

# (Optional) Report the overall AUC of prediction in the training cohort
Rscript npsR/nps_train_AUC.R testdata/Test1/npsdat/ 0 20 40 60
# (Optional) Generate a plot of overall shrinkage curves
Rscript npsR/nps_plot_shrinkage.R testdata/Test1/npsdat/ Test1.nps.pdf 0 20 40 60

# Convert back to per-SNP effect sizes
bsub -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test1/npsdat/ 0
bsub -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test1/npsdat/ 20
bsub -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test1/npsdat/ 40
bsub -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test1/npsdat/ 60

# Check the results
./nps_check.sh back2snpeff testdata/Test1/npsdat/ 0 20 40 60

# Calculate polygenic scores for each chromosome and for each individual in the validation cohort
bsub -J score[1-22] lsf/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 0
bsub -J score[1-22] lsf/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 20
bsub -J score[1-22] lsf/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 40
bsub -J score[1-22] lsf/nps_score.job testdata/Test1/npsdat/ testdata/Test1/ Test1.val 60

# Check the results
./nps_check.sh score testdata/Test1/npsdat/ testdata/Test1/ Test1.val 0 20 40 60

# Calculate overall polygenic scores and report prediction accuracies
Rscript npsR/nps_val.R testdata/Test1/npsdat/ testdata/Test1/ testdata/Test1/Test1.val.5K.fam testdata/Test1/Test1.val.5K.phen 0 20 40 60 
```

### Running NPS on Test set #2 using SGE clusters

For Test set #2 and real data, it is not practical to run it on desktop computures for heavy computational demand. Running NPS on Test set #2 is similar to the case of Test set #1. However, since Test set #2 has a total of ~5,000,000 genome-wide common SNPs, we recommend to use the window size of **4,000 SNPs**. And accordingly, window shifts should be set to **0, 1,000, 2,000, and 3,000 SNPs**. 

**Note: Some of NPS steps now require large memory space. For the most of data we tested, 4GB memory limit is sufficient to run individual NPS tasks. The memory limit can be specified by `-l h_vmem=4G`.**

```bash
cd nps-1.0.0/

# Standardize genotypes
qsub -cwd -t 1-22 sge/nps_stdgt.job testdata/Test2/ Test2.train

# Check the results
./nps_check.sh stdgt testdata/Test2/ Test2.train

# Configure
# This step requires large memory space.
Rscript npsR/nps_init.R testdata/Test2/Test2.summstats.txt testdata/Test2 testdata/Test2/Test2.train.2.5K_2.5K.fam testdata/Test2/Test2.train.2.5K_2.5K.phen Test2.train 4000 testdata/Test2/npsdat

# Check the results
./nps_check.sh init testdata/Test2/npsdat/

# Transform data to the decorrelate eigenlocus space
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_decor.job testdata/Test2/npsdat/ 0
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_decor.job testdata/Test2/npsdat/ 1000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_decor.job testdata/Test2/npsdat/ 2000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_decor.job testdata/Test2/npsdat/ 3000

# Check the results
./nps_check.sh decor testdata/Test2/npsdat/ 0 1000 2000 3000

# Prune correlations across windows
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_prune.job testdata/Test2/npsdat/ 0
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_prune.job testdata/Test2/npsdat/ 1000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_prune.job testdata/Test2/npsdat/ 2000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_prune.job testdata/Test2/npsdat/ 3000

# Check the results
./nps_check.sh prune testdata/Test2/npsdat/ 0 1000 2000 3000

# Separate the GWAS-significant partition
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_gwassig.job testdata/Test2/npsdat/ 0
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_gwassig.job testdata/Test2/npsdat/ 1000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_gwassig.job testdata/Test2/npsdat/ 2000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_gwassig.job testdata/Test2/npsdat/ 3000

# Check the results
./nps_check.sh gwassig testdata/Test2/npsdat/ 0 1000 2000 3000

# Define partitioning boundaries for the rest of data
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 0 10 10
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 1000 10 10
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 2000 10 10
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 3000 10 10

# Check the results
./nps_check.sh prep_part testdata/Test2/npsdat/ 0 1000 2000 3000

# Calculate partitioned risk scores in the training cohort
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_part.job testdata/Test2/npsdat/ 0
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_part.job testdata/Test2/npsdat/ 1000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_part.job testdata/Test2/npsdat/ 2000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_part.job testdata/Test2/npsdat/ 3000

# Check the results
./nps_check.sh part testdata/Test2/npsdat/ 0 1000 2000 3000

# Estimate per-partition shrinkage weights
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 0
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 1000
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 2000
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 3000

# Check the results
./nps_check.sh weight testdata/Test2/npsdat/ 0 1000 2000 3000

# (Optional) Report the overall AUC of prediction in the training cohort
Rscript npsR/nps_plot_shrinkage.R testdata/Test2/npsdat/ Test2.nps.pdf 0 1000 2000 3000

# (Optional) Generate a plot of overall shrinkage curves
Rscript npsR/nps_train_AUC.R testdata/Test2/npsdat/ 0 1000 2000 3000


qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_back2snpeff.job testdata/Test2/npsdat/ 0
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_back2snpeff.job testdata/Test2/npsdat/ 1000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_back2snpeff.job testdata/Test2/npsdat/ 2000
qsub -cwd -l h_vmem=4G -t 1-22 sge/nps_back2snpeff.job testdata/Test2/npsdat/ 3000

# Check the results
./nps_check.sh back2snpeff testdata/Test2/npsdat/ 0 1000 2000 3000

# Convert back to per-SNP effect sizes
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 0
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 1000
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 2000
qsub -cwd -t 1-22 sge/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 3000

# Check the results
./nps_check.sh score testdata/Test2/npsdat/ testdata/Test2/ Test2.val 0 1000 2000 3000

# Calculate polygenic scores for each chromosome and for each individual in the validation cohort
Rscript npsR/nps_val.R testdata/Test2/npsdat/ testdata/Test2/ testdata/Test2/Test2.val.5K.fam testdata/Test2/Test2.val.5K.phen 0 1000 2000 3000
```

The following AUC is reported in the training cohort by `nps_train_AUC.R`:
> Data: 2500 controls < 2500 cases.  
> Area under the curve: 0.7843  
> 95% CI: 0.7718-0.7968 (DeLong)  

The shrinkage curve generated by `nps_plot_shrinkage.R` is [here](https://github.com/sgchun/nps/blob/master/testdata/Test1.nps.pdf). 

`nps_val.R` reports the following overall prediction accuracy in the validation cohort: 
> Non-Parametric Shrinkage 1.0.0  
> Validation cohort:  
> Total  5000 samples  
> 240  case samples  
> 4760  control samples  
> 0  samples with missing phenotype (-9)  
> Includes TotalLiability  
> Checking a prediciton model (winshift = 0 )...  
> Observed-scale R2 = 0.04862955   
> Liability-scale R2 = 0.2303062   
> Checking a prediciton model (winshift = 1000 )...  
> Observed-scale R2 = 0.04994584  
> Liability-scale R2 = 0.2298484  
> Checking a prediciton model (winshift = 2000 )...  
> Observed-scale R2 = 0.05150205  
> Liability-scale R2 = 0.2268046  
> Checking a prediciton model (winshift = 3000 )...  
> Observed-scale R2 = 0.05258402  
> Liability-scale R2 = 0.2298871  
>  
>  
>  
> Producing a combined prediction model...OK (saved in testdata/Test2/Test2.val.5K.phen.nps_score )  
> Observed-scale R2 = 0.05253146  
> Liability-scale R2 = 0.2376991  
> Loading required package: pROC  
> Type 'citation("pROC")' for a citation.  
>  
> Attaching package: ‘pROC’  
>  
> The following objects are masked from ‘package:stats’:  
>  
> cov, smooth, var  
>  
> AUC:  
>  
> Call:  
> roc.default(controls = prisk[vlY == 0], cases = prisk[vlY ==     1], ci = TRUE)  
>   
> Data: 4760 controls < 240 cases.  
> Area under the curve: 0.7886  
> 95% CI: 0.7617-0.8154 (DeLong)  
> Loading required package: DescTools  
> Nagelkerke's R2 = 0.1668188   
>  
> Call: &nbsp;glm(formula = vlY ~ prisk, family = binomial(link = "logit"))  
>  
> Coefficients:  
> (Intercept) &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;prisk  
> &nbsp; &nbsp; -5.2888 &nbsp; &nbsp; &nbsp; 0.2387  
>  
> Degrees of Freedom: 4999 Total (i.e. Null);  4998 Residual  
> Null Deviance: &nbsp; &nbsp; &nbsp;1926  
> Residual Deviance: 1652 &nbsp; &nbsp; &nbsp; &nbsp; AIC: 1656  
> Done  

### Running NPS on Test set #2 using LSF clusters

Running NPS on LSF is similar to running it on SGE clusters. The memory limit is specified by `bsub -R 'rusage[mem=4000]'`

```bash
cd nps-1.0.0/

# Standardize genotypes
bsub -J stdgt[1-22] lsf/nps_stdgt.job testdata/Test2/ Test2.train

# Check the results
./nps_check.sh stdgt testdata/Test2/ Test2.train 

# Configure
# This step requires large memory space.  
Rscript npsR/nps_init.R testdata/Test2/Test2.summstats.txt testdata/Test2 testdata/Test2/Test2.train.2.5K_2.5K.fam testdata/Test2/Test2.train.2.5K_2.5K.phen Test2.train 4000 testdata/Test2/npsdat 

# Check the results
./nps_check.sh init testdata/Test2/npsdat/

# Transform data to the decorrelate eigenlocus space
bsub -R 'rusage[mem=4000]' -J decor[1-22] lsf/nps_decor.job testdata/Test2/npsdat/ 0 
bsub -R 'rusage[mem=4000]' -J decor[1-22] lsf/nps_decor.job testdata/Test2/npsdat/ 1000 
bsub -R 'rusage[mem=4000]' -J decor[1-22] lsf/nps_decor.job testdata/Test2/npsdat/ 2000 
bsub -R 'rusage[mem=4000]' -J decor[1-22] lsf/nps_decor.job testdata/Test2/npsdat/ 3000 

# Check the results
./nps_check.sh decor testdata/Test2/npsdat/ 0 1000 2000 3000

# Prune correlations across windows
bsub -R 'rusage[mem=4000]' -J prune[1-22] lsf/nps_prune.job testdata/Test2/npsdat/ 0 
bsub -R 'rusage[mem=4000]' -J prune[1-22] lsf/nps_prune.job testdata/Test2/npsdat/ 1000 
bsub -R 'rusage[mem=4000]' -J prune[1-22] lsf/nps_prune.job testdata/Test2/npsdat/ 2000 
bsub -R 'rusage[mem=4000]' -J prune[1-22] lsf/nps_prune.job testdata/Test2/npsdat/ 3000 

# Check the results
./nps_check.sh prune testdata/Test2/npsdat/ 0 1000 2000 3000

# Separate the GWAS-significant partition
bsub -R 'rusage[mem=4000]' -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test2/npsdat/ 0 
bsub -R 'rusage[mem=4000]' -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test2/npsdat/ 1000 
bsub -R 'rusage[mem=4000]' -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test2/npsdat/ 2000 
bsub -R 'rusage[mem=4000]' -J gwassig[1-22] lsf/nps_gwassig.job testdata/Test2/npsdat/ 3000 

# Check the results
./nps_check.sh gwassig testdata/Test2/npsdat/ 0 1000 2000 3000

# Define partitioning boundaries for the rest of data
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 0 10 10
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 1000 10 10
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 2000 10 10
Rscript npsR/nps_prep_part.R testdata/Test2/npsdat/ 3000 10 10

# Check the results
./nps_check.sh prep_part testdata/Test2/npsdat/ 0 1000 2000 3000

# Calculate partitioned risk scores in the training cohort
bsub -R 'rusage[mem=4000]' -J part[1-22] lsf/nps_part.job testdata/Test2/npsdat/ 0 
bsub -R 'rusage[mem=4000]' -J part[1-22] lsf/nps_part.job testdata/Test2/npsdat/ 1000 
bsub -R 'rusage[mem=4000]' -J part[1-22] lsf/nps_part.job testdata/Test2/npsdat/ 2000 
bsub -R 'rusage[mem=4000]' -J part[1-22] lsf/nps_part.job testdata/Test2/npsdat/ 3000 

# Check the results
./nps_check.sh part testdata/Test2/npsdat/ 0 1000 2000 3000

# Estimate per-partition shrinkage weights
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 0 
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 1000 
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 2000 
Rscript npsR/nps_weight.R testdata/Test2/npsdat/ 3000 

# Check the results
./nps_check.sh weight testdata/Test2/npsdat/ 0 1000 2000 3000

# (Optional) Report the overall AUC of prediction in the training cohort
Rscript npsR/nps_plot_shrinkage.R testdata/Test2/npsdat/ Test2.nps.pdf 0 1000 2000 3000 

# (Optional) Generate a plot of overall shrinkage curves
Rscript npsR/nps_train_AUC.R testdata/Test2/npsdat/ 0 1000 2000 3000 

# Convert back to per-SNP effect sizes
bsub -R 'rusage[mem=4000]' -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test2/npsdat/ 0 
bsub -R 'rusage[mem=4000]' -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test2/npsdat/ 1000 
bsub -R 'rusage[mem=4000]' -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test2/npsdat/ 2000 
bsub -R 'rusage[mem=4000]' -J back2snpeff[1-22] lsf/nps_back2snpeff.job testdata/Test2/npsdat/ 3000 

# Check the results
./nps_check.sh back2snpeff testdata/Test2/npsdat/ 0 1000 2000 3000

# Calculate polygenic scores for each chromosome and for each individual in the validation cohort
bsub -J score[1-22] lsf/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 0
bsub -J score[1-22] lsf/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 1000
bsub -J score[1-22] lsf/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 2000
bsub -J score[1-22] lsf/nps_score.job testdata/Test2/npsdat/ testdata/Test2/ Test2.val 3000

# Check the results
./nps_check.sh score testdata/Test2/npsdat/ testdata/Test2/ Test2.val 0 1000 2000 3000

# Calculate polygenic scores for each chromosome and for each individual in the validation cohort
Rscript npsR/nps_val.R testdata/Test2/npsdat/ testdata/Test2/ testdata/Test2/Test2.val.5K.fam testdata/Test2/Test2.val.5K.phen 0 1000 2000 3000 
```

## How to prepare training and validation cohorts for NPS
We take an example of UK Biobank to show how to prepare training and validation cohorts for NPS. In principle, however, NPS can work with other cohorts as far as the genotype data are prepared in the bgen file format. To gain access to UK Biobank, please check [UK Biobank data access application procedure](https://www.ukbiobank.ac.uk/). 

### Using UK Biobank as a training cohort
UK Biobank data consist of the following files: 
- **ukb_imp_chrN_v3.bgen**: imputed allelic dosages for chrN
- **ukb_mfi_chrN_v3.txt**: marker information for ukb_imp_chrN_v3.bgen
- **ukb31063.sample**: bgen sample file for the entire cohort 

Assuming that UK Biobank dataset is located in `<path_to_ukbb>/`, we first exclude SNPs with minor allele frequency < 5% or imputation quality (INFO) score < 0.4 by running the following:   
```bash
qsub -l h_vmem=4G -t 1-22 support/common_snps.job <path_to_ukbb>/ukb_imp_chr#_v3.bgen <path_to_ukbb>/ukb_mfi_chr#_v3.txt <work_dir>
```
The output files will be stored in `<work_dir>/`.

Next, we filter bgen files to include only training cohort samples (as specified in `<sample_id_file>`) and then export the genotypes into dosage files. The `<sample_id_file>` is simply a list of sample IDs, with one sample in each line. This can be done by running the following: 
```bash
qsub -l h_vmem=4G -t 1-22 support/filter_samples.job <path_to_ukbb>/ukb31063.sample <work_dir> <sample_id_file> <training_cohort_name>
```  

Then, we harmonize GWAS summary statitics with training cohort data. The following step will harmonize `<summary_statistics_file>` in the *MINIMAL* format with training cohort data and generate the harmonized GWAS summary statistics in the *PREFORMATTED* format: 
```bash
Rscript support/harmonize_summstats.R <summary_statistics_file> <work_dir> <training_cohort_name>
```

After that, we need to filter out SNPs that were flagged for removal during the above harmonization step by running the following: 
```bash
qsub -l h_vmem=4G -t 1-22 support/filter_variants.job <work_dir> <training_cohort_name>
```

Finally, the following step will create `<work_dir>/<training_cohort_name>.fam`, which keeps tracks of the IDs of all training cohort samples: 
```bash
support/make_fam.sh <work_dir> <training_cohort_name>
```

Overall, the job scripts will automatially generate the following NPS input files: 
- `<work_dir>/<training_cohort_name>.preformatted_summstats.txt`
- `<work_dir>/chromN.<training_cohort_name>.QC2.dosage.gz`
- `<work_dir>/<training_cohort_name>.fam`

**Note:**
* common_snps.job and filter_samples.job will use bgenix and qctool, respectively. The job scripts may need to be moditifed to load these modules.
* The job scripts in `support/` directory is for SGE clusters but can be easily modified for LSF or other cluster systems.
* The job scripts use memory space up to 4GB (run with `qsub -l h_vmem=4G`). Depending on summary statistics, `support/harmonize_summstats.R` can take memory up to ~8GB. `support/harmonize_summstats.R` will terminate abruptly if it runs out of memory.

### Using a different cohort as a training cohort 

To use other cohort as a training cohort, you will need to generate marker information files similar to **ukb_mfi_chrN_v3.txt** in UK Biobank. We can generate these files from bgen files (**<dataset_dir>/chromN.bgen**) as follows:
```bash
qsub -t 1-22 support/make_snp_info.job <dataset_dir>/chrom#.bgen <work_dir>
```
Internally, `support/make_snp_info.job` uses **qctool**, thus the job script may need to be modified to load the module if needed. The marker information files will be named as **<work_dir>/chromN.mfi.txt**. 

The rest of steps are straight-forward and similar to processing UK Biobank data: 
```bash
qsub -l h_vmem=4G -t 1-22 support/common_snps.job <dataset_dir>/chrom#.bgen <work_dir>/chrom#.mfi.txt <work_dir>
qsub -l h_vmem=4G -t 1-22 support/filter_samples.job <bgen_sample_file_of_entire_cohort> <work_dir> <sample_id_file> <training_cohort_name>
Rscript support/harmonize_summstats.R <summary_statistics_file> <work_dir> <training_cohort_name>
qsub -l h_vmem=4G -t 1-22 support/filter_variants.job <work_dir> <training_cohort_name>
support/make_fam.sh <work_dir> <training_cohort_name>
```

### Using UK Biobank for validation as well as training cohorts
UK Biobank can be split into two and used as a validation as well as training cohort. Assume that `<sample_id_file>` contains the IDs of samples to include in the validation cohort. Then, validation cohort data can be prepared for NPS with UK Biobank in the following steps: 
```bash
cp <work_dir>/<training_cohort_name>.UKBB_rejected_SNPIDs <work_dir>/<validation_cohort_name>.UKBB_rejected_SNPIDs

qsub -t 1-22 support/filter_samples.job <path_to_ukbb>/ukb31063.sample <work_dir> <sample_id_file> <validation_cohort_name>
qsub -t 1-22 support/filter_variants.job <work_dir> <validation_cohort_name>
support/make_fam.sh <work_dir> <validation_cohort_name>
```
The `<training_cohort_name>.UKBB_rejected_SNPIDs` file contains the list of SNPs that were rejected while preparing a training cohort. By coping it into a validation cohort and running `support/filter_variants.job` will make sure that training and validation cohorts will have the same set of markers.  

### Using a validation cohort that are independent from a training cohort

To run NPS on a cohort that is independent from a training cohort, we provide `sge/nps_harmonize_val.job` and `lsf/nps_harmonize_val.job` scripts. Let us  assuming that the genotype files of this cohort are named as **<dataset_dir>/chromN.bgen**, this can be done as follows:
```
qsub -l h_vmem=4G sge/nps_harmonize_val.job <nps_data_dir> <dataset_dir>/chrom#.bgen <bgen_sample_file_of_entire_cohort> <work_dir> <cohort_name>
```
* **Note: nps_harmonize_val.job relies on qctool internally. The codes may need to be modified to load qctool module.**
* **Note: The generated file names will be as chromN.<cohort_name>.dosage.gz. DatasetTag will be just <cohort_name>.**
