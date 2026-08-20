#!/bin/bash
# =============================================================
#  PHÂN TÍCH DỮ LIỆU PHIM TMDB BẰNG LỆNH LINUX
#  Dữ liệu vào : tmdb.tsv  (sinh ra từ 00_prep.sh)
#  Các cột     : 1 id | 2 imdb_id | 3 popularity | 4 budget | 5 revenue
#                6 original_title | 7 cast | 8 homepage | 9 director
#                10 tagline | 11 keywords | 12 overview | 13 runtime
#                14 genres | 15 production_companies | 16 release_date
#                17 vote_count | 18 vote_average | 19 release_year
#                20 budget_adj | 21 revenue_adj
# =============================================================
# Không dùng "pipefail" vì các pipeline dạng `sort ... | head -1` sẽ khiến
# `sort` nhận tín hiệu SIGPIPE và bị coi là lỗi.
set -eu
cd "$(dirname "$0")"

F=tmdb.tsv
TAB=$'\t'
mkdir -p ketqua

hr() { printf '=%.0s' {1..64}; echo; }

# -------------------------------------------------------------
hr; echo "CÂU 1 — Sắp xếp phim theo NGÀY PHÁT HÀNH GIẢM DẦN"; hr
# head -1  : giữ lại dòng tiêu đề
# tail -n +2 : bỏ dòng tiêu đề rồi mới sort
# sort -t'\t' -k16,16 -r : sort theo cột 16 (release_date, dạng YYYY-MM-DD),
#                          -r = đảo ngược (giảm dần = mới nhất trước)
{ head -1 "$F"; tail -n +2 "$F" | sort -t"$TAB" -k16,16r; } > ketqua/1_sap_xep_theo_ngay.tsv

echo "-> Đã lưu: ketqua/1_sap_xep_theo_ngay.tsv ($(( $(wc -l < ketqua/1_sap_xep_theo_ngay.tsv) - 1 )) phim)"
echo "5 phim mới nhất:"
awk -F"$TAB" 'NR>1 && NR<=6 {printf "   %s  %s\n", $16, $6}' ketqua/1_sap_xep_theo_ngay.tsv
echo "5 phim cũ nhất:"
tail -5 ketqua/1_sap_xep_theo_ngay.tsv | awk -F"$TAB" '{printf "   %s  %s\n", $16, $6}'

# -------------------------------------------------------------
hr; echo "CÂU 2 — Lọc phim có ĐIỂM ĐÁNH GIÁ TRUNG BÌNH > 7.5"; hr
# awk so sánh số học trên cột 18 (vote_average)
# +$18 ép kiểu chuỗi -> số
{ head -1 "$F"; awk -F"$TAB" 'NR>1 && ($18+0) > 7.5' "$F"; } > ketqua/2_diem_tren_7.5.tsv

N2=$(( $(wc -l < ketqua/2_diem_tren_7.5.tsv) - 1 ))
echo "-> Đã lưu: ketqua/2_diem_tren_7.5.tsv"
echo "   Số phim đạt yêu cầu: $N2 / $(( $(wc -l < $F) - 1 ))"
echo "   10 phim điểm cao nhất trong nhóm này:"
awk -F"$TAB" 'NR>1{printf "%s\t%s\t(%s lượt vote)\n", $18, $6, $17}' ketqua/2_diem_tren_7.5.tsv \
  | sort -t"$TAB" -k1,1nr | head -10 | awk -F"$TAB" '{printf "   %-5s %s %s\n", $1, $2, $3}'

# -------------------------------------------------------------
hr; echo "CÂU 3 — Phim có DOANH THU CAO NHẤT và THẤP NHẤT"; hr
echo ">> Doanh thu CAO NHẤT:"
awk -F"$TAB" 'NR>1' "$F" | sort -t"$TAB" -k5,5nr | head -3 \
  | awk -F"$TAB" '{printf "   %s (%s) — %.0f USD\n", $6, $19, $5}'

echo
echo ">> Doanh thu THẤP NHẤT (tính cả các dòng revenue = 0):"
awk -F"$TAB" 'NR>1' "$F" | sort -t"$TAB" -k5,5n | head -1 \
  | awk -F"$TAB" '{printf "   %s (%s) — %d USD\n", $6, $19, $5}'
Z=$(awk -F"$TAB" 'NR>1 && ($5+0)==0' "$F" | wc -l)
echo "   LƯU Ý: có $Z phim ghi revenue = 0 — đây là DỮ LIỆU THIẾU, không phải"
echo "   phim thực sự không thu được đồng nào. Nên loại bỏ khi so sánh:"
echo
echo ">> Doanh thu THẤP NHẤT (chỉ xét phim có revenue > 0):"
awk -F"$TAB" 'NR>1 && ($5+0)>0' "$F" | sort -t"$TAB" -k5,5n | head -3 \
  | awk -F"$TAB" '{printf "   %s (%s) — %d USD\n", $6, $19, $5}'

# -------------------------------------------------------------
hr; echo "CÂU 4 — TỔNG DOANH THU của tất cả các bộ phim"; hr
awk -F"$TAB" 'NR>1 { s += $5; if ($5+0>0) n++ }
     END {
       printf "   Tổng doanh thu (danh nghĩa) : %.0f USD  (~%.2f tỷ USD)\n", s, s/1e9
       printf "   Số phim có số liệu doanh thu: %d\n", n
       printf "   Doanh thu trung bình / phim : %.0f USD\n", s/n
     }' "$F"
# revenue_adj = doanh thu đã quy đổi về USD năm 2010 (loại trừ lạm phát)
awk -F"$TAB" 'NR>1 { s += $21 }
     END { printf "   Tổng doanh thu đã chỉnh lạm phát (revenue_adj): %.0f USD (~%.2f tỷ USD)\n", s, s/1e9 }' "$F"

# -------------------------------------------------------------
hr; echo "CÂU 5 — TOP 10 phim có LỢI NHUẬN cao nhất (revenue - budget)"; hr
awk -F"$TAB" 'NR>1 {
        loi = $5 - $4;                       # lợi nhuận = doanh thu - kinh phí
        printf "%.0f\t%s\t%s\t%.0f\t%.0f\n", loi, $6, $19, $4, $5
     }' "$F" \
  | sort -t"$TAB" -k1,1nr | head -10 \
  | awk -F"$TAB" 'BEGIN{printf "   %-3s %-34s %-6s %12s %14s %14s\n","#","Tên phim","Năm","Kinh phí","Doanh thu","Lợi nhuận"}
       { printf "   %-3d %-34.34s %-6s %12.0f %14.0f %14.0f\n", NR, $2, $3, $4, $5, $1 }'

echo
echo "   (Tham khảo — TOP 5 theo lợi nhuận ĐÃ CHỈNH LẠM PHÁT: revenue_adj - budget_adj)"
awk -F"$TAB" 'NR>1 { printf "%.0f\t%s\t%s\n", $21-$20, $6, $19 }' "$F" \
  | sort -t"$TAB" -k1,1nr | head -5 \
  | awk -F"$TAB" '{ printf "   %-3d %-34.34s %-6s %14.0f\n", NR, $2, $3, $1 }'

# -------------------------------------------------------------
hr; echo "CÂU 6 — ĐẠO DIỄN và DIỄN VIÊN xuất hiện nhiều nhất"; hr
# Cột 9 (director) và cột 7 (cast) có thể chứa NHIỀU tên, ngăn cách bằng '|'
# => tách mỗi tên ra 1 dòng rồi dùng sort | uniq -c (thành ngữ kinh điển của Linux)
echo ">> TOP 10 ĐẠO DIỄN nhiều phim nhất:"
awk -F"$TAB" 'NR>1 && $9!="" { n=split($9,a,"|"); for(i=1;i<=n;i++) print a[i] }' "$F" \
  | sort | uniq -c | sort -nr | head -10 \
  | awk '{c=$1; $1=""; sub(/^ /,""); printf "   %-3d %-28s %3d phim\n", NR, $0, c}'

echo
echo ">> TOP 10 DIỄN VIÊN đóng nhiều phim nhất:"
awk -F"$TAB" 'NR>1 && $7!="" { n=split($7,a,"|"); for(i=1;i<=n;i++) print a[i] }' "$F" \
  | sort | uniq -c | sort -nr | head -10 \
  | awk '{c=$1; $1=""; sub(/^ /,""); printf "   %-3d %-28s %3d phim\n", NR, $0, c}'

# -------------------------------------------------------------
hr; echo "CÂU 7 — THỐNG KÊ SỐ LƯỢNG PHIM THEO THỂ LOẠI"; hr
# Cột 14 (genres) cũng ngăn cách bằng '|' — 1 phim có thể thuộc nhiều thể loại
# nên TỔNG các thể loại sẽ LỚN HƠN tổng số phim.
awk -F"$TAB" 'NR>1 && $14!="" { n=split($14,a,"|"); for(i=1;i<=n;i++) print a[i] }' "$F" \
  | sort | uniq -c | sort -nr > ketqua/7_thong_ke_the_loai.txt

awk '{c=$1; $1=""; sub(/^ /,""); printf "   %-20s %5d phim\n", $0, c}' ketqua/7_thong_ke_the_loai.txt
echo "   -----------------------------------"
echo "   Số thể loại khác nhau: $(wc -l < ketqua/7_thong_ke_the_loai.txt)"
NOG=$(awk -F"$TAB" 'NR>1 && $14==""' "$F" | wc -l)
echo "   Phim không ghi thể loại: $NOG"
echo "   -> Đã lưu: ketqua/7_thong_ke_the_loai.txt"

# -------------------------------------------------------------
hr; echo "XUẤT THÊM BẢN .CSV (mở được bằng Excel) — vẫn bằng awk thuần"; hr
# Quy tắc CSV chuẩn: ô nào chứa dấu phẩy, ngoặc kép hoặc khoảng trắng đầu/cuối
# thì phải bọc trong ngoặc kép, và ngoặc kép bên trong phải nhân đôi ("").
tsv2csv() {
  awk -F"$TAB" '{
      out = ""
      for (i = 1; i <= NF; i++) {
          f = $i
          if (f ~ /[",]/) { gsub(/"/, "\"\"", f); f = "\"" f "\"" }
          out = (i == 1) ? f : out "," f
      }
      print out
  }' "$1" > "$2"
}
for f in ketqua/1_sap_xep_theo_ngay ketqua/2_diem_tren_7.5; do
  tsv2csv "$f.tsv" "$f.csv"
  echo "   -> $f.csv ($(wc -l < "$f.csv") dòng)"
done

hr; echo "HOÀN TẤT. Các file kết quả nằm trong thư mục ./ketqua/"; hr
ls -la ketqua/
