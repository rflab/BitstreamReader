#ifndef _RF_BITSTREAM__
#define _RF_BITSTREAM__

#include <string>
#include <memory>

// コンパイラ依存
#if defined(_MSC_VER) && (_MSC_VER >= 1800)
#elif defined(__GNUC__) && __cplusplus >= 201300L // __GNUC_PREREQ(4, 9)
#else
#endif

namespace rf
{
	using std::string;
	using std::unique_ptr;
	using std::streambuf;
	using std::ios;
	
	class Bitstream
	{
	private:

		unique_ptr<streambuf> buf_;
		int size_;
		int bit_pos_;
		int byte_pos_;

	protected:

		// メンバ変数にstreambufを同期する
		bool sync();

	public:
		
		Bitstream();

		// このBitstreamの現在サイズ
		int size() const;

		// 読み取りヘッダのビット位置
		int bit_pos() const;

		// 読み取りヘッダのバイト位置
		int byte_pos() const;

		// 読み込み対象のstreambufを設定する
		// サイズの扱いをもっとねらないとだめだかなぁ
		//template<typename Deleter>
		bool assign(unique_ptr<streambuf>&& buf, int size);

		// ストリームにデータを追記する
		bool write_byte_string(const char *buf, int size);

		// ストリームに１バイト追記する
		bool put_char(char c);

		// ビット単位でストリーム内か判定
		bool check_bit(int bit) const;

		// バイト単位でストリーム内か判定
		bool check_byte(int byte) const;

		// ビット単位で現在位置＋offsetがストリーム内か判定
		bool check_offset_bit(int offset) const;

		// バイト単位で現在位置＋offsetがストリーム内か判定
		bool check_offset_byte(int offset) const;

		// 読み込みヘッダを移動
		bool seekpos(int byte, int bit);

		// ビット単位で読み込みヘッダを移動
		bool seekpos_bit(int offset);

		// バイト単位で読み込みヘッダを移動
		bool seekpos_byte(int offset);

		// 読み込みヘッダを移動
		bool seekoff(int byte, int bit);

		// ビット単位で読み込みヘッダを移動
		bool seekoff_bit(int offset);

		// バイト単位で読み込みヘッダを移動
		bool seekoff_byte(int offset);

		// ビット単位で読み込み
		bool read_bit(int size, uint32_t &ret_value);

		// バイト単位で読み込み
		bool read_byte(int size, uint32_t &ret_value);

		// 指数ゴロムとしてビット単位で読み込み
		bool read_expgolomb(uint32_t &ret_value, int &ret_size);

		// 文字列として読み込み
		// NULL文字が先に見つかった場合はその分だけポインタを進める
		// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
		bool read_string(int max_length, string &ret_str);

		// ビット単位で先読み
		bool look_bit(int size, uint32_t &ret_val);

		// バイト単位で先読み
		bool look_byte(int size, uint32_t &ret_val);

		// 指数ゴロムで先読み
		bool look_expgolomb(uint32_t &ret_val);

		// 指定バッファの分だけ先読み
		bool look_byte_string(char* address, int size);
		
		// 特定の１バイトの値を検索
		// 見つからなければファイル終端を返す
		bool find_byte(char sc, int &ret_offset, bool advance, int end_offset = INT_MAX);

		// 特定のバイト列を検索
		// 見つからなければファイル終端を返す
		bool find_byte_string(const char* address, int size, int &ret_offset, bool advance, int end_offset = INT_MAX);
	};

	class RingBuf final : public streambuf
	{
	private:

		unique_ptr<char[]> buf_;
		int size_;

	protected:

		int overflow(int c) override;
		int underflow() override;
		ios::pos_type seekoff(ios::off_type off, ios::seekdir way, ios::openmode) override;
		ios::pos_type seekpos(ios::pos_type pos, ios::openmode which) override;

	public:

		RingBuf();
		bool reserve(int size); // リングバッファのサイズを指定する

	};
}

#endif
