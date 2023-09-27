#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TAM 200


typedef struct pc { char service[4];
                    int src;
                    int PE;
                    char payload[6];
                    int stamp;
                    int flag;
                   } pck;



int separador(char car)
 {
  switch(car)
   { case ' ': case ':': case '=': case ')': case '(': case ',': case '\n': case '\t': case '\r': return 1;
     default: return 0;
   }
}

/***********************************
* Retorna uma string da linha lida *
***********************************/
int search_word(char *word, int *counter, char *token)
{
    int k = 0;

    while (separador(word[*counter]))
        (*counter)++;
    while (!separador(word[*counter]) && word[*counter] != '\0')
        token[k++] = word[(*counter)++];
    token[k] = '\0';
    return k;
}

/**********************************************************************/
 // ROTINA PARA LER UMA LINHA - BY MORAES
/**********************************************************************/
int getline_moraes(char *word, int limit, FILE *p1)
{   int    i = 0;
    char   c;

    while ((c = getc(p1)) != '\n') {
        if (c == EOF)
            return 0;
        word[i] = c;
        if(++i==limit) 
             { printf("\ERROR : line too large %s %d\n", word, (int)(strlen(word))); 
               fflush(stdout);
               exit(1); 
             }
    }

    word[i] = 0x00;   // TIRA O \n  DA STRING

    return 1;
}



 
///-------------------------------------------------------------------------------
int main(int argc, char *argv[])
//-------------------------------------------------------------------------------
{
  FILE *fp;     
  int PEs, i, d, pe, x, y, nb_pacotes, cont_excess_packets, cont_errors;
  char line[TAM], wd[5][TAM], word[10];
  pck *pacotes;

  cont_excess_packets =  cont_errors = 0 ;

  puts("*****************************************************************************************************");
  printf("*  WAFORM GENERATOR AND BRNOC VERIFICATION.   Usage:  %s v {verbose - more signals in the waveform} \n", argv[0]);
  puts("*****************************************************************************************************"); 
  d=0;
  if (argc==2) d=1;

   // parser do cenario para encontrar o tamanho do sistema  //////////////////////////////////////
   if ((fp = fopen( "cenario.vhd", "r")) == NULL) { printf("Erro abrindo o arquivo cenario.vhd !\n");  return 0; }
   while (getline_moraes(line, TAM, fp))
     {   
        for(i=d=0; d<5; d++)
          search_word(line, &i, wd[d]);

        if( !strcasecmp(wd[1], "PEsX"))
            sscanf(wd[3], "%d", &x );

        if( !strcasecmp(wd[1], "PEsY"))
             sscanf(wd[3], "%d", &y );
     }
   fclose(fp);

   PEs = x * y;

  printf("%d %d %d\n", x, y, PEs);

  if ((fp = fopen( "wave.do", "w")) == NULL) { printf("Erro abrindo o arquivo  !\n");  return 0; }

  fprintf(fp, "onerror {resume}\n");
  fprintf(fp, "quietly WaveActivateNextPane {} 0\n" );
  fprintf(fp, "add wave -noupdate /tb/clock\n");

  for(i=0; i<PEs; i++) 
        fprintf(fp,"add wave -noupdate -expand -group USED_TABLE -color Red /tb/brNoC/proc(%d)/seek/used_table\n", i);

 for(i=0; i<PEs; i++) {
        fprintf(fp,"add wave -noupdate -group router_%d -color white /tb/brNoC/BrOutPort(%d)(4).source\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d -color white /tb/brNoC/BrOutPort(%d)(4).target\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/EA_Output\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/EA_Input\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/table\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/outPort(4).service\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/outPort(4).payload\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color {Dark Orchid} /tb/br_local_ports_OUT_req(%d)\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color {Dark Orchid} /tb/br_local_ports_IN_ack(%d)\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color Red /tb/br_local_ports_IN_req(%d)\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color Red /tb/br_local_ports_OUT_ack(%d)\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/sel_port\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/sel\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/inPort\n", i, i);
        if (d) fprintf(fp,"add wave -noupdate -group router_%d /tb/brNoC/proc(%d)/seek/free_index\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color white /tb/brNoC/proc(%d)/seek/inPort_req\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color white /tb/brNoC/proc(%d)/seek/outPort_req\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color blue /tb/brNoC/proc(%d)/seek/inPort_ack\n", i, i);
        fprintf(fp,"add wave -noupdate -group router_%d -color blue /tb/brNoC/proc(%d)/seek/outPort_ack\n", i, i);
      }

  for(i=0; i<PEs; i++) 
        fprintf(fp,"add wave -noupdate -expand -group PENDING /tb/brNoC/proc(%d)/seek/pending_table\n", i);
  
  fprintf(fp,"TreeUpdate [SetDefaultTree]\n");
  fprintf(fp,"WaveRestoreCursors {{Cursor 1} {1138 ns} 0}\n");
  fprintf(fp,"quietly wave cursor active 1\n");
  fprintf(fp,"configure wave -namecolwidth 352\n");
  fprintf(fp,"configure wave -valuecolwidth 100\n");
  fprintf(fp,"configure wave -justifyvalue left\n");
  fprintf(fp,"configure wave -signalnamewidth 0\n");
  fprintf(fp,"configure wave -snapdistance 10\n");
  fprintf(fp,"configure wave -datasetprefix 0\n");
  fprintf(fp,"configure wave -rowmargin 4\n");
  fprintf(fp,"configure wave -childrowmargin 2\n");
  fprintf(fp,"configure wave -gridoffset 0\n");
  fprintf(fp,"configure wave -gridperiod 1\n");
  fprintf(fp,"configure wave -griddelta 40\n");
  fprintf(fp,"configure wave -timeline 0\n");
  fprintf(fp,"configure wave -timelineunits ns\n");
  fprintf(fp,"update\n");
  fprintf(fp,"WaveRestoreZoom {0 ns} {12600 ns}\n");
  fclose(fp);






   ////////////////////////////////////////////////// determina o número de pacotes totalAAAAAAAAA
   nb_pacotes = 0;
   for(pe=0; pe<PEs; pe++) {

         fp = fopen( "cenario.vhd", "r");

         while (getline_moraes(line, TAM, fp))
           {   
              for(i=d=0; d<5; d++)
                  search_word(line, &i, wd[d]);

              if( !strcasecmp(wd[4], "brALL_SERVICE"))
                 { sscanf(wd[1], "%d", &d );
                     if(d != pe)
                        nb_pacotes++;
                 }

               if( !strcasecmp(wd[4], "brTgt_SERVICE"))
                 { sscanf(wd[2], "%d", &d );
                     if(d == pe)
                       nb_pacotes++;
                 }
           }
         fclose(fp);
    }

    pacotes=  calloc(nb_pacotes+1, sizeof(pck));
    
    nb_pacotes = 0;
    
    ////////////////////////////////////////////////// monta a estrutura da dados 
    for(pe=0; pe<PEs; pe++) {

         fp = fopen( "cenario.vhd", "r");

         while (getline_moraes(line, TAM, fp))
           {   
              for(i=d=0; d<5; d++)
                  search_word(line, &i, wd[d]);

              sscanf(wd[1], "%d", &(pacotes[nb_pacotes].src) );
              pacotes[nb_pacotes].PE = pe;
              pacotes[nb_pacotes].flag = 0;
              pacotes[nb_pacotes].payload[0] = wd[3][2];
              pacotes[nb_pacotes].payload[1] = wd[3][3];
              pacotes[nb_pacotes].payload[2] = '\0';
              sscanf(wd[0], "%d", &(pacotes[nb_pacotes].stamp) );

              if( !strcasecmp(wd[4], "brALL_SERVICE"))
                 { sscanf(wd[1], "%d", &d );
                   if(d != pe)
                        { //printf( "ALL %2d from:%s  %s t:%s\n", pe, wd[1], wd[3], wd[0]);
                          strcpy(pacotes[nb_pacotes].service, "ALL");
                          nb_pacotes++;
                         }
                 }

               if( !strcasecmp(wd[4], "brTgt_SERVICE"))
                 { sscanf(wd[2], "%d", &d );
                     if(d == pe)
                        { //printf( "TGT %2d from:%s  %s t:%s\n", pe, wd[1], wd[3], wd[0]);
                          strcpy(pacotes[nb_pacotes].service, "TGT");
                          nb_pacotes++;
                         }
                 }
           }
         fclose(fp);
         //puts("");
    }

   
    ////////////////////////////////////////////////// now open the log
    if ((fp = fopen( "brNoC_log.txt", "r")) == NULL) { printf("Erro abrindo o arquivo brNoC_log !\n");  return 0; }

    while (getline_moraes(line, TAM, fp))
      if( strlen(line)>0 )
       {  
            char flag, lsvc[4], lpld[6];
            int  lPE, lsrc, lstamp;
            
            i=0;
            search_word(line, &i, lsvc);
            search_word(line, &i, word);   // PE
            sscanf( word, "%d", &lPE );
            search_word(line, &i, word);   // from
            search_word(line, &i, word);   // src
            sscanf( word, "%d", &lsrc );
            search_word(line, &i, lpld);   // payload
            search_word(line, &i, word);   // tgetline_moraes
            search_word(line, &i, word);   // timestamp
            sscanf( word, "%d", &lstamp );

            for(flag=i=0; i<nb_pacotes; i++) 
              if( !pacotes[i].flag) 
                  if( pacotes[i].PE==lPE && pacotes[i].src==lsrc && !strcmp(pacotes[i].payload,lpld) &&  !strcmp(pacotes[i].service,lsvc) )
                   {   printf("[%2d]--- PE:%2d   src:%2d   p:%s  s:%5d  %s  LATENCIA:%3d\n", i+1, pacotes[i].PE,
                             pacotes[i].src, pacotes[i].payload, pacotes[i].stamp, pacotes[i].service, lstamp-pacotes[i].stamp );
                       pacotes[i].flag = 1;
                       flag = 1;
                       break;
                   }
            if( !flag )
              { printf(" ERRO - PACOTE GERADO A MAIS- PE:%2d   src:%2d   p:%s  s:%5d  service:%s\n", lPE, lsrc, lpld, lstamp, lsvc  );
                cont_excess_packets ++;
              }
       }

    for(i=0; i<nb_pacotes; i++) 
       if( !pacotes[i].flag )
        { printf(" ERRO -  PACOTE [%d] NAO RECEBIDO - PE:%2d   src:%2d   p:%s  s:%5d  service:%s\n", i+1, pacotes[i].PE,
                      pacotes[i].src, pacotes[i].payload, pacotes[i].stamp, pacotes[i].service  );
          cont_errors ++ ;
        }

   
   printf("\n-----> Number of not delivered packets: %4d", cont_errors);
   printf("\n-----> Number of extra packets: %4d\n", cont_excess_packets);


   printf("\n-----> Number of processors: %4d\n", PEs);
   printf(  "-----> Number of packets:    %4d\n", nb_pacotes);

   fclose(fp);
   return 0;


}