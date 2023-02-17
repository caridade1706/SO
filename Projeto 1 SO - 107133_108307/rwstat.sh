#!/bin/bash

# Trabalho realizado por:
# Roberto Rolão de Castro 107133
# Tiago Caridade Gomes 108307

declare -A dadosInfo=()     # Guarda a informação de cada processo, sendo a 'chave' o PID (ARRAY ASSOCIATIVO)
declare -A argumentos=()    # Guarda a informação das opções passadas como argumentos (ARRAY ASSOCIATIVO)
declare -A ReadB=()         # Guarda a informação do rchar lido antes do sleep, sendo a 'chave' o PID (ARRAY ASSOCIATIVO)
declare -A WriteB=()        # Guarda a informação do wchar lido antes do sleep, sendo a 'chave' o PID (ARRAY ASSOCIATIVO)

i=0                         # Variável usada na condição de verificação de opções de ordenação
re='^[0-9]+([.][0-9]+)?"$'  # Variável usada para verificar se outra variável é um dígito

verif_argu(){

    if [[ $@ == 'vazio' || $@ =~ $re ]]; then
        echo "ERRO: Argumento de uma das opções não foi preenchido ou foi mal preenchido!!" >&2
        exit 1
    fi
}

verif_data(){
    
    formatData='^((Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)) +[0-9]{1,2} +[0-9]{1,2}:[0-9]{1,2}'
    if  [[ $@ =~ $re || ! $@ =~ $formatData ]]; then
        echo "ERRO: Data introduzida inválida"
        exit 1
    fi
}

function menu()
{
    if [[ $@ == '"' ]]; then
        echo "ERRO: Insira pelo menos um argumento (segundos)."
        exit 1
    fi

    if ! [[ ${@: -1} =~ $re ]]; then
        echo "ERRO: Último argumento tem de ser um número."
        exit 1
    fi

    while getopts ":s:c:u:e:m:M:wrp:" option; do

        #Adicionar ao array argumentos as opcoes passadas ao correr o rwstat.sh, caso existam adiciona as que são passadas, caso não, adiciona "vazio"
        
        if [[ -r "$OPTARG" ]]; then
            argumentos[$option]="vazio"
        else
            argumentos[$option]="${OPTARG}"
        fi

        case $option in
        
        c) #Seleção de processos a utilizar atraves de uma expressão regular
            argu=${argumentos['c']}
            verif_argu $argu
            ;;
        s) #Seleção de processos a visualizar num periodo temporal - data mínima
            data=${argumentos['s']}
            verif_data $data
            ;;
        e) #Seleção de processos a visualizar num periodo temporal - data máxima
            data=${argumentos['e']}
            verif_data $data
            ;;
        u) #Seleção de processos a visualizar através do nome do utilizador
            argu=${argumentos['u']}
            verif_argu $argu
            ;;
       
        m) #Seleção dos processos com maior PID do que o argumento passado 
            argu=${argumentos['m']}
            if ! [[ $argu'"' =~ $re ]]; then
                printf "ERRO: Argumento passado (%s) não é um número!\n" "$argu"
                exit 1
            fi
            ;;

        M) #Seleção dos processos com menor PID do que o argumento passado 
            argu=${argumentos['M']}
            if ! [[ $argu'"' =~ $re ]]; then
                printf "ERRO: Argumento passado (%s) não é um número!\n" "$argu"
                exit 1
            fi
            ;;
        p) #Número de processos a visualizar
            argu=${argumentos['p']}
            if ! [[ $argu'"' =~ $re ]]; then
                printf "ERRO: Argumento passado (%s) não é um número!\n" "$argu"
                exit 1
            fi
            ;;  
        r) #Ordenação inversa
            ;;
        w) #Ordenação da tabela pelos 'write values' (WRITEB)
            ;;
        *) #Passagem de argumentos inválidos
            echo "ERRO: Expressão inválida ($OPTARG)"
            exit 1
            ;;
        esac 
    done

    
}

#Tratamento dos dados lidos
function processamentoDados() {

    for entry in /proc/[[:digit:]]*; do
        if [[ -r $entry/status && -r $entry/io ]]; then
            PID=$(cat $entry/status | grep -w Pid | tr -dc '0-9')    # ir buscar o PID
            rchaReadB=$(cat $entry/io | grep rchar | tr -dc '0-9')   # rchar inicial
            wchaReadB=$(cat $entry/io | grep wchar | tr -dc '0-9')   # wchar inicial

            if [[ $rchaReadB == 0 && $wchar == 0 ]]; then
                continue
            else
                ReadB[$PID]=$(printf "%12d\n" "$rchaReadB")
                WriteB[$PID]=$(printf "%12d\n" "$wchaReadB")
            fi
        fi

    done

    sleep $1 # tempo em espera

    for entry in /proc/[[:digit:]]*; do

        if [[ -r $entry/status && -r $entry/io ]]; then

            PID=$(cat $entry/status | grep -w Pid | tr -dc '0-9') # ir buscar o PID
            user=$(ps -o user= -p $PID)                           # ir buscar o user do PID

            comm=$(cat $entry/comm | tr " " "_") # ir buscar o comm,e retirar os espaços e substituir por '_' nos comm's com 2 nomes

            #Seleção de processos a utilizar atraves de uma expressão regular
            if [[ -v argumentos[c] && ! $comm =~ ${argumentos['c']} ]]; then
                continue
            fi

            LANG=en_us_8859_1
            startDate=$(ps -o lstart= -p $PID) # data de início do processo atraves do PID
            startDate=$(date +"%b %d %H:%M" -d "$startDate")
            dateSeg=$(date -d "$startDate" +"%b %d %H:%M"+%s | awk -F '[+]' '{print $2}') # data do processo em segundos

            if [[ -v argumentos[s] ]]; then                                                       # Opção -s (data mínima)
                start=$(date -d "${argumentos['s']}" +"%b %d %H:%M"+%s | awk -F '[+]' '{print $2}') 

                if [[ "$dateSeg" -lt "$start" ]]; then
                    continue
                fi
            fi

            if [[ -v argumentos[e] ]]; then                                                       # Opção -e (data máxima)
                end=$(date -d "${argumentos['e']}" +"%b %d %H:%M"+%s | awk -F '[+]' '{print $2}') 

                if [[ "$dateSeg" -gt "$end" ]]; then
                    continue
                fi
            fi

            rchar2=$(cat $entry/io | grep rchar | tr -dc '0-9') # rchar apos s segundos
            wchar2=$(cat $entry/io | grep wchar | tr -dc '0-9') # wchar apos s segundos
            subr=$(($rchar2-${ReadB[$PID]}))
            subw=$(($wchar2-${WriteB[$PID]}))
            rateR=$(echo "scale=2; $subr/$1" | bc -l) # calculo do rateR
            rateW=$(echo "scale=2; $subw/$1" | bc -l) # calculo do rateW

            if [[ -v argumentos[m] || -v argumentos[M] || -v argumentos[u] ]]; then
                
                if [[ -v argumentos[m] && -v argumentos[M] ]]; then

                   
                    num=${argumentos[m]}
                    
                    num2=${argumentos[M]}
                    
                    if [[ $PID -ge $num && $PID -le $num2 ]]; then
                        dadosInfo[$PID]=$(printf "%-27s %-16s %15d %12d %12d %15s %15s %16s\n" "$comm" "$user" "$PID" "$subr" "$subw" "$rateR" "$rateW" "$startDate")
                    fi
                
                
                elif [[ -v argumentos[m] ]]; then

                    num=${argumentos[m]}
                    if [[ $PID -ge $num ]]; then
                        dadosInfo[$PID]=$(printf "%-27s %-16s %15d %12d %12d %15s %15s %16s\n" "$comm" "$user" "$PID" "$subr" "$subw" "$rateR" "$rateW" "$startDate")
                    fi
                
                
                elif [[ -v argumentos[M] ]]; then

                    num=${argumentos[M]}
                    if [[ $PID -le $num ]]; then
                        dadosInfo[$PID]=$(printf "%-27s %-16s %15d %12d %12d %15s %15s %16s\n" "$comm" "$user" "$PID" "$subr" "$subw" "$rateR" "$rateW" "$startDate")
                    fi
                
                
                else
                    userDado=${argumentos[u]}
                
                    if [ "$userDado" == "$user" ]; then
                        
                        dadosInfo[$PID]=$(printf "%-27s %-16s %15d %12d %12d %15s %15s %16s\n" "$comm" "$user" "$PID" "$subr" "$subw" "$rateR" "$rateW" "$startDate")
                    
                    else
                        printf "User (%s) não encontrado.\n" "$userDado"
                        exit
                    fi
                fi

            else
                dadosInfo[$PID]=$(printf "%-27s %-16s %15d %12d %12d %15s %15s %16s\n" "$comm" "$user" "$PID" "$subr" "$subw" "$rateR" "$rateW" "$startDate") 
            fi
        fi
    done

}

function imprimir() {
    printf "%-27s %-16s %15s %12s %12s %15s %15s %16s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER" "RATEW" "DATE"

    #Ordenação inversa da tabela (ordem crescente do RATER)
    if   [[ -v argumentos[r] ]]; then 
        ordem="-rn"
    else
        ordem="-n"
    fi

    #Caso não haja nenhum valor atribuido a p, este toma de valor do tamanho do array, imprimindo a informação toda
    if ! [[ -v argumentos[p] ]]; then
        p=${#dadosInfo[@]}
    #Nº de processos que queremos ver
    else
        p=${argumentos['p']}
    fi

    #Ordenação da tabela pelos 'write values' (RATEW)
    if [[ -v argumentos[w] ]]; then

        if [[ "$ordem" == "-rn" ]]; then
            ordem="-n"
        else
            ordem="-rn"
        fi

        printf '%s \n' "${dadosInfo[@]}" | sort  -k7 $ordem | head -n $p
    elif [[ "$ordem" == "-rn" ]]; then
        printf '%s \n' "${dadosInfo[@]}" | sort  -k6 | head -n $p
    else
        #Ordenação default da tabela (ordem decrescente do RATER)
        printf '%s \n' "${dadosInfo[@]}" | sort  -k6 -rn | head -n $p
    fi

}

menu "$@\""
processamentoDados ${@: -1} 
imprimir