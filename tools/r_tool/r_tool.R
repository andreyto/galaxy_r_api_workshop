args <- commandArgs(TRUE)
summ_exp <- args[1]
pdf_out = args[2]
library(bcbioRNASeq)
bcb = readRDS(summ_exp)
print(summ_exp)
print(pdf_out)
pdf(file=pdf_out)
plotTotalReads(bcb)
#dev.off()
