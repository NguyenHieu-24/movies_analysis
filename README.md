# Project 01: Movie Dataset Processing via Linux Command Line

<div align="center">
  <img src="https://img.shields.io/badge/OS-Linux-FCC624?logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/Role-Data%20Engineering-blue" alt="Data Engineering">
</div>

## 📌 Project Overview
This repository contains shell scripts and command line instructions to perform preliminary data analysis and data extraction on a movie dataset stored on a Linux server. The tasks focus on fundamental Data Engineering skills: parsing, filtering, aggregating, and summarizing text-based data files using built-in POSIX utilities (`sort`, `awk`, `grep`, `cut`, `uniq`, `tr`).

## 🗂 Dataset Assumption
For the bash commands below to function correctly, we assume the dataset is a comma-separated values (CSV) file named `tmdb-movies.csv` with the following structure (header included):
`id,imdb_id,popularity,budget,revenue,original_title,...`

---

## 🚀 Tasks & Solutions

### 1. Sort movies by release date (descending) and save to a new file
```bash
{ head -1 tmdb.tsv ; tail -n +2 tmdb.tsv | sort -t$'\t' -k16,16r ; } > q1.tsv
head -6 q1.tsv | cut -f6,16
```

### 2. Filter movies with an average rating > 7.5 and save to a new file
```bash
{ head -1 tmdb.tsv ; awk -F'\t' 'NR>1 && $18>7.5' tmdb.tsv ; } > q2.tsv
awk -F'\t' 'NR>1 && $18>7.5' tmdb.tsv | wc -l
```

### 3. Find movies with the highest and lowest revenue
```bash
# Highest Revenue (Sorting column 5 in reverse numeric)
sort -t$'\t' -k5,5nr tmdb.tsv | head -1 | awk -F'\t' '{print $6, "-", $5, "USD"}'

# Lowest Revenue (Sorting column 5 in numeric ascending)
awk -F'\t' 'NR>1 && $5 > 0' tmdb.tsv | sort -t$'\t' -k5,5n | head -1 | awk -F'\t' '{print $6, "-", $5, "USD"}'
```

### 4. Calculate the total revenue of all movies
```bash
# Sum the values in column 5 skipping the header
awk -F'\t' 'NR>1 { tong += $5 } END { print "Tong doanh thu:", tong, "USD" }' tmdb.tsv
awk -F'\t' 'NR>1 { tong += $5 } END { printf "Tong: %.2f ty USD\n", tong/1000000000 }' tmdb.tsv
```

### 5. Top 10 movies with the highest profit
```bash
# Sort by profit (column 6) descending and take the top 10
awk -F'\t' 'NR>1 { print $5-$4 "\t" $6 }' tmdb.tsv | sort -k1,1nr | head -10
```

### 6. Directors and Actors with the most movies
```bash
# Director with the most movies (Column 7)
awk -F'\t' 'NR>1 { n=split($9,a,"|"); for(i=1;i<=n;i++) print a[i] }' tmdb.tsv | sort | uniq -c | sort -nr | head -10

# Actor with the most movies (Column 8, splitting multiple actors by '|')
awk -F'\t' 'NR>1 { n=split($7,a,"|"); for(i=1;i<=n;i++) print a[i] }' tmdb.tsv | sort | uniq -c | sort -nr | head -10
```

### 7. Count movies by genre
```bash
# Split genres (Column 9) separated by '|', count occurrences, and sort descending
awk -F'\t' 'NR>1 { n=split($14,a,"|"); for(i=1;i<=n;i++) print a[i] }' tmdb.tsv | sort | uniq -c | sort -nr > q7.txt
cat q7.txt
awk '{tong += $1} END {print "Tong:", tong}' q7.txt
```

---

## 🛠 Usage & Execution
1. Ensure your dataset is named `tmdb-movies.csv` and is located in the same directory as your terminal session.
2. Adjust the `-k` (sort key), `-f` (cut field), and `$N` (awk variable) parameters in the commands based on the exact column index of your actual dataset.
3. Run the commands directly in your Linux bash terminal.

## 👥 Author
**Hieu Nguyen** - Data Engineer
