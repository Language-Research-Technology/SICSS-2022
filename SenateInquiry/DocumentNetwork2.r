## packages

library(tm)
library(igraph)

## load data
senate_data <- read.csv('G:/LDaCA/Training/SCISS/Data/submission_file_categorisation_content.csv')

## join text from each author group 
fed_gov_text <- paste(subset(senate_data, Category == "FedGov")[,7], collapse = ' ')
hed_text <- paste(subset(senate_data, Category == "HEd")[,7], collapse = ' ')
individ_text <- paste(subset(senate_data, Category == "Individ")[,7],collapse = ' ')
loc_gov_text <- paste(subset(senate_data, Category == "LocGov")[,7], collapse = ' ')
ngo_text <- paste(subset(senate_data, Category == "NGO")[,7], collapse = ' ')

## create Corpus object
texts <- c(fed_gov_text, hed_text, individ_text, loc_gov_text, ngo_text)
docs <- Corpus(VectorSource(texts))

## inspect
str(as.character(docs[[2]]))

## preprocessing
docs <-tm_map(docs,content_transformer(tolower))
docs <- tm_map(docs, removePunctuation)
docs <- tm_map(docs, removeNumbers)
docs <- tm_map(docs, removeWords, stopwords("english"))
docs <- tm_map(docs, stripWhitespace)
docs <- tm_map(docs, stemDocument)

## inspect again
str(as.character(docs[[2]]))

## create a term-document matrix, make it a data frame
TDM <- TermDocumentMatrix(docs)
dim(TDM)
TDM <- as.matrix(TDM)
TDM_df <- as.data.frame(TDM)
colnames(TDM_df) <- c('fedGov', 'HEd', 'Indiv','LocGov','NGO')

## add columns to data frame: total number of occurrences in docs, number of docs in which a term appears
TDM_df$freq <- apply(TDM_df, sum, MARGIN = 1)

## function gets number of docs where term occurs
in_docs <- function(rowx) {
  number = 5
  for (value in rowx) {
    if (value == 0) {number <- number - 1}
  }
  return(number)
}

in_doc_vector <- apply(TDM_df, in_docs, MARGIN = 1)
TDM_df$inDocs <- in_doc_vector
str(TDM_df)

## get token counts for each group of docs
token_counts <- apply(TDM_df, sum, MARGIN = 2)

## set variables for getting plot data
## words in how many groups of documents? (2,3,4)
doc_groups <- 3
## number of words to include
word_count <- 20
## most frequent or least frequent? values 'most', 'least'
freq <- 'most'

plot_data <- subset(TDM_df, TDM_df$inDocs == doc_groups)
plot_data <- plot_data[order(plot_data$freq),]
if (freq == 'most') {
  plot_data <- plot_data[(nrow(plot_data) - word_count):(nrow(plot_data)),]
} else if (freq == "least") {
  plot_data <- plot_data[1:word_count,]
}

## make edge table
edge_list <- list()
sources <- c('FedGov', 'HEd','Indiv','LocGov','NGO')

for (j in 1:nrow(plot_data)) {
  edges_y <- list()
  data_row <- plot_data[j,]
  for (i in 1:5) {
    if (as.numeric(data_row[i]) != 0) {
      edges_y[[i]] <- c(rownames(data_row), sources[i], data_row[i]/token_counts[i])
    }
  }
  edges_y = edges_y[-which(sapply(edges_y, is.null))]
  edges_y <- do.call(rbind, edges_y)
  edge_list <- rbind(edge_list, edges_y)
}

edge_list_df <-as.data.frame(edge_list)
colnames(edge_list_df) <- c('term','doc','weight')

## make the graph object
bi_plot <- graph.data.frame(edge_list_df, directed = FALSE)

## check that the graph object is bipartite and assign type values
bipartite.mapping(bi_plot)
V(bi_plot)$type <- bipartite_mapping(bi_plot)$type

## set circle for doc groups only
V(bi_plot)$shape <- ifelse(V(bi_plot)$type == TRUE, "circle", "none")

## view plot
plot(bi_plot, layout = layout.bipartite)

