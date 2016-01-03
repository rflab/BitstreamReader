#ifndef __RF_SQLWRAPPER__
#define __RF_SQLWRAPPER__

#include <string>
#include <vector>
#include "sqlite3.h"

namespace rf
{
	namespace wrapper
	{
		class SqliteWrapper final
		{
		private:

			std::string filename_;
			sqlite3* db_;
			std::vector<sqlite3_stmt*> stmts_;

			void close();
			void open(const std::string& filename);
			SqliteWrapper(){}

		public:

			void exec(const std::string& sql);
			int prepare(const std::string& sql);
			void reset(int stmt_ix);
			int step(int stmt_ix);
			
			void bind_int(int stmt_ix, int sql_ix, int value);
			void bind_text(int stmt_ix, int sql_ix, const std::string &text);
			void bind_real(int stmt_ix, int sql_ix, double value);
			void bind_blob(int stmt_ix, int sql_ix, const void* blob, int size, void(*destructor)(void*));
			
			int         column_count(int stmt_ix);
			std::string column_name(int stmt_ix, int colmun);
			int         column_type(int stmt_ix, int column);
			int         column_int(int stmt_ix, int column);
			std::string column_text(int stmt_ix, int column);
			double      column_real(int stmt_ix, int column);
			const void* column_blob(int stmt_ix, int column);
			
			SqliteWrapper(const std::string& filename);
			~SqliteWrapper();
		};
	}
}

#endif
