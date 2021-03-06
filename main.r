## ---- eval=FALSE, include=TRUE-------------------------------------------------------
## "Protocolo:
##  1. Daniel Felipe Villa Rengifo
##  2. Lenguaje: R
##  3. Tema: Text mining con R: ejemplo práctico Twitter
##  4. Fuentes:
##     https://rpubs.com/Joaquin_AR/334526"


## ------------------------------------------------------------------------------------
# Para Trabajar estos ejercicios descargaremos las siguientes librerias:
#install.packages("rtweet")
library(rtweet)
library(tidyverse)
#install.packages("tm")
library(tm)
#install.packages("wordcloud2")
library(wordcloud2)
#install.packages("topicmodels")
library(topicmodels)
#install.packages("LDAvis")
library(LDAvis)
#install.packages("tsne")
library(tsne)


## ------------------------------------------------------------------------------------
# Descargas de tweets con rtweet

# Vamos a filtrar por un tema especifico con tags: "q = tag OR tag OR ..."
# La muestra es de "n = 18.000" twets
# de todos os tweets sin algun otro filtro: "type = "mixed""
# incluir retweets: "include_rts = FALSE"
# lenguaje Español: "lang = es"

# Vamos a filtrar las busquedas por los vivido en Colombia

"Profe se me olvido que si lo vuelvo a correr twiter me limita tenia 18.000 pero al volverlo a correr me dejo solo 5.375 asi que trabajaremos con ellos"

rt <- search_tweets(q = "ParoNacional OR ColombiaNoPara OR SOSColombia OR Colombia OR MarchenenPaz OR NosEstanMatando OR Presidente Duque OR Comite de Paro OR Paro",type = "mixed", n = 18000, include_rts = FALSE,
                    lang='es')

# Guardamos los tweets en formato que R los pueda trabajar (.RDS)
saveRDS(rt,'fuentes/rt.RDS')


## ------------------------------------------------------------------------------------
# Leemos los archivos descargados:
rt <- read_rds('fuentes/rt.RDS')

# Mostramos los archvivos con los que trabajeremos (10 aleatorios)

rt %>% 
  #saca una muestra de la base dando n numeros
  sample_n(10)

# Visualizemos los primeros 10
muestra <- rt$text[1:10]
write.table(muestra,file = "Muestra10.txt", row.names = F)

#Nos da los tweets de desde el mes pasado hasta el dia de hoy.
range(rt$created_at)


## ------------------------------------------------------------------------------------
# Grafiquemos la frecuencia de los tweets solicitados, es decir cada tanto van a la app y envian texto:
png(filename = "FreqTweets.png")

freqtweets <- rt %>%
  ts_plot("3 hours") +
  ggplot2::theme_minimal() +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold")) +
  ggplot2::labs(
    x = "FECHA", y = "# de Tweets",
    title = "Frecuencia de los tweets relacionados al Paro Nacional",
    subtitle = "Agregado a intervalos de tres horas")

freqtweets
dev.off()


## ------------------------------------------------------------------------------------
# Ahora como vemos no necesitamos todas las variables de rt, solamente el texto, ya que eso lo que utilizaremos para este Dia:

# Creamos una varaible donde contenga todo el texto de los tweets
texto <-  rt$text 
# Veamos los 10:
texto[1:10]


## ------------------------------------------------------------------------------------
# Creamos un vector tipo corpus para trabajarlo de manera mas sencilla:
myCorpus = Corpus(VectorSource(texto))


## ------------------------------------------------------------------------------------
#################Con la función `tm_map`#############################


## ------------------------------------------------------------------------------------
# Convertimos todo a minuscula:
myCorpus = tm_map(myCorpus, content_transformer(tolower))


## ------------------------------------------------------------------------------------
#Sacar la puntuación
myCorpus = tm_map(myCorpus, removePunctuation)


## ------------------------------------------------------------------------------------
#Sacar los números
myCorpus = tm_map(myCorpus, removeNumbers)


## ------------------------------------------------------------------------------------
# Sacar las Palabras vacías (StopWords)
myCorpus = tm_map(myCorpus, removeWords, stopwords(kind = "es"))


## ------------------------------------------------------------------------------------
# Como ya filtramos la busqueda con las palabras anteriormente utlizadas, entonces
# También deberíamos sacar las palabras que utilizamos para descargar la información

# Creamos el vector de palabras para eliminar:
delstart <- c("ParoNacional","ColombiaNoPara", "SOSColombia", "Colombia","MarchenenPaz", "NosEstanMatando", "Presidente Duque", "Comite de Paro OR Paro")

# Con la funcion removeWords eliminamos si contiene algunas de estas palabras:
myCorpus = tm_map(myCorpus, removeWords, delstart)


## ------------------------------------------------------------------------------------
# AHora inspeccionamos los resultados con la función inspect()
inspect(myCorpus[1:10])

"podemos ver que nos quedaron unos que son la forma de representar el “enter”. Lo mejor sería eliminarlos."

"También queremos sacar los links. Para eso vamos a usar expresiones regulares (tema que voy a ver si tratare en los replits) para definir el patron que tiene un link, y luego crearemos una función que los elimine."


## ------------------------------------------------------------------------------------
# Instalamos la paqueteria necesaria:

#devtools::install_github("VerbalExpressions/RVerbalExpressions")
library(RVerbalExpressions)


## ------------------------------------------------------------------------------------
# Vamos a crear una expresion que nso identifique lo que tenemos que eliminar en ese orden
expresion <- rx() %>%
  # añadimos los "http"
  rx_find('http') %>% 
  # si algunos de los http tiene s es decir, https tambien agregelo
  rx_maybe('s') %>% 
  #como ya lo pasamos por los otros filtros, ya no deberia haber puntuacion, pero por si las dudas
  rx_maybe('://') %>%
  # Eliminamos los stopwords
  rx_anything_but(value = ' ')

print(expresion)

# Para entender mejor el concepto los aplicamos a el sigueinte texto
txt <- "comité nacional  paro llama   corredor humano  darle  bienvenida   cidh  colombia hoy domingo   junio    am   aeropuerto  toda     bogotá httpstcoydadidrp"

# Aplicamos una funcion de la libreria
library(stringr)
print(str_remove_all(txt, pattern = expresion))

#Lo pasamos por el corpus

# Vamos a iterar los textos, despues con la funcion anterior eliminaremos el texto según el patron de expresion:

myCorpus = tm_map(myCorpus, content_transformer(function(x) str_remove_all(x, pattern = expresion)))

# Ahora vamos hacer algo similar, eliminaremos los todos los "enter" o "\n" de los tweets
myCorpus = tm_map(myCorpus, content_transformer(function(x) str_remove_all(x, pattern = '\n')))

# Inspeccionamos los resultados:
inspect(myCorpus[1:10])


## ------------------------------------------------------------------------------------
#Creamos una matriz de Término-documento:
myDTM = DocumentTermMatrix(myCorpus, control = list(minWordLength = 1))

# Podemos ver en una fila en "#" del tweet y a un lado las palabras que quedaron en uan frecuencia de cada una:
inspect(myDTM)

# Ahora veamos un requento de las palabras:
palabras_frecuentes <- findMostFreqTerms(myDTM,n = 25, INDEX = rep(1,nDocs(myDTM)))[[1]]

# Ahora lo pasamos a formato tibble (datos limpios tipo "data.frame")
palabras_frecuentes <- tibble(word = names(palabras_frecuentes), freq =palabras_frecuentes)

# Exportamos
write.table(palabras_frecuentes, file = "RecuentoDePalabrasTweet.txt", row.names = F)