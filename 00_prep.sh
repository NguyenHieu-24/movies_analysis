# BƯỚC 0 - CHUẨN HOÁ DỮ LIỆU  (100% COMMAND LINE, KHÔNG DÙNG PYTHON)
# BA VẤN ĐỀ CỦA FILE tmdb-movies.csv:
#
#   (1) Có ô được bọc trong dấu ngoặc kép và BÊN TRONG chứa DẤU PHẨY:
#         ...,"Twenty-two years after the events of Jurassic Park, Isla...",124,...
#       => `cut -d,` hay `awk -F,` sẽ đếm sai số cột.
#
#   (2) Có ô chứa cả KÝ TỰ XUỐNG DÒNG => 1 bộ phim bị trải trên nhiều dòng
#       (file có 10.879 dòng vật lý nhưng chỉ 10.866 bộ phim).
#       => `wc -l` đếm sai, `awk` xử lý sai.
#
#   (3) Ngày dạng M/D/YY (6/9/15) không sắp xếp được bằng `sort`.
#
# CÁCH GIẢI (chỉ bằng awk - một công cụ chuẩn POSIX có sẵn trên mọi server):
#   - Gộp các dòng vật lý thành 1 bản ghi hoàn chỉnh bằng quy tắc
#     "số dấu ngoặc kép phải CHẴN thì bản ghi mới kết thúc".
#   - Tách trường theo dấu phẩy nhưng nối lại những mảnh nằm trong ngoặc kép.
#   - Xuất ra TSV (phân tách bằng TAB - ký tự không tồn tại trong dữ liệu).
#   - Đổi ngày sang YYYY-MM-DD để `sort` dùng được ngay.

set -eu
cd "$(dirname "$0")"

IN=tmdb-movies.csv
OUT=tmdb.tsv

awk '
# Hàm bỏ ngoặc kép bao ngoài và giải mã "" thành " 
function unquote(s) {
    if (substr(s,1,1) == "\"" && substr(s,length(s),1) == "\"" && length(s) >= 2) {
        s = substr(s, 2, length(s)-2)
        gsub(/""/, "\"", s)
    }
    return s
}

# Hàm đổi 6/9/15 -> 2015-06-09
function iso(d,   p, y) {
    if (split(d, p, "/") != 3) return d
    y = p[3] + 0
    y = (y >= 30) ? y + 1900 : y + 2000     # dữ liệu TMDB trải từ 1960 -> 2015
    return sprintf("%04d-%02d-%02d", y, p[1], p[2])
}

# Hàm tách một bản ghi CSV thành mảng F[], trả về số trường
function parse_csv(rec,   n, i, a, buf, dang_mo, nf) {
    n  = split(rec, a, ",")     # cắt thô theo dấu phẩy
    nf = 0
    dang_mo = 0
    for (i = 1; i <= n; i++) {
        # nếu trường trước còn dở (ngoặc kép chưa đóng) thì NỐI LẠI dấu phẩy vừa bị cắt
        buf = dang_mo ? buf "," a[i] : a[i]

        # đếm số dấu ngoặc kép trong buf; gsub thay " bằng " nên nội dung KHÔNG đổi,
        # ta chỉ mượn giá trị trả về của gsub để đếm
        if (gsub(/"/, "\"", buf) % 2 == 0) {
            dang_mo = 0
            F[++nf] = unquote(buf)          # ngoặc kép đã cân bằng -> trường hoàn chỉnh
        } else {
            dang_mo = 1                     # còn dở, đợi mảnh tiếp theo
        }
    }
    if (dang_mo) F[++nf] = unquote(buf)     # phòng trường hợp dữ liệu lỗi
    return nf
}

# Hàm in một bản ghi ra dạng TSV
function xuat(nf,   i, out) {
    out = ""
    for (i = 1; i <= nf; i++) {
        gsub(/\t|\r/, " ", F[i])            # dọn TAB / CR còn sót để giữ TSV 1-dòng-1-phim
        out = (i == 1) ? F[i] : out "\t" F[i]
    }
    print out
}

# Xử lý chính
{
    sub(/\r$/, "")                          # bỏ ký tự CR nếu file dạng Windows

    # GỘP DÒNG: nối tiếp cho tới khi số dấu ngoặc kép của bản ghi là số CHẴN
    rec = (rec == "") ? $0 : rec " " $0
    tmp = rec
    if (gsub(/"/, "\"", tmp) % 2 != 0) next     # còn lẻ -> bản ghi chưa hết, đọc dòng sau

    nf = parse_csv(rec)
    rec = ""

    if (NR == 1) {                          # dòng tiêu đề: giữ nguyên, chỉ đổi định dạng
        SO_COT = nf
        xuat(nf)
        next
    }

    if (nf != SO_COT) { bo_qua++; next }     # dòng hỏng -> bỏ, có báo cáo ở cuối

    F[16] = iso(F[16])                      # cột 16 = release_date
    xuat(nf)
    dem++
}

END {
    printf "Đã chuyển %d bộ phim sang TSV", dem  > "/dev/stderr"
    if (bo_qua) printf " (bỏ qua %d dòng hỏng)", bo_qua > "/dev/stderr"
    printf "\n" > "/dev/stderr"
}
' "$IN" > "$OUT"

echo "Số cột : $(head -1 "$OUT" | awk -F'\t' '{print NF}')"
echo "Số phim: $(( $(wc -l < "$OUT") - 1 ))"

# TỰ KIỂM TRA: mọi dòng phải đúng 21 cột 
LOI=$(awk -F'\t' 'NF != 21' "$OUT" | wc -l)
echo "Dòng sai số cột: $LOI  (phải bằng 0)"

# TỰ KIỂM TRA: năm suy ra từ release_date phải khớp cột release_year
LECH=$(awk -F'\t' 'NR>1 { split($16,d,"-"); if (d[1] != $19) c++ } END { print c+0 }' "$OUT")
echo "Ngày lệch so với release_year: $LECH  (phải bằng 0)"
