#include "sqlwrapper.h"

using namespace rf;
using namespace rf::wrapper;

void SqliteWrapper::close()
{
	for (auto stmt : stmts_)
	{
		sqlite3_finalize(stmt);
	}

	int ret = sqlite3_close(db_);
	if (FAIL(ret == SQLITE_OK))
	{
		ERR << "close error." << endl;
		throw runtime_error(FAIL_STR("file close error."));
	}
}

void SqliteWrapper::open(const std::string& filename)
{
	int ret = sqlite3_open(filename.c_str(), &db_);
	if (FAIL(ret == SQLITE_OK))
	{
		ERR << "open error." << endl;
		throw runtime_error(FAIL_STR("file open error."));
	}

	//auto deleter = [](sqlite3* db){
	//	int e = sqlite3_close(db);
	//	if (e != SQLITE_OK){
	//		ERR << "close error." << endl;
	//	}
	//};
	//unique_ptr<sqlite3*> p(&db);
	//db_ = std::move(p);
}

void SqliteWrapper::exec(const std::string& sql)
{
	// テーブルの作成
	char *msg = nullptr;
	int ret = sqlite3_exec(db_, sql.c_str(), NULL, NULL, &msg);
	if (FAIL(ret == SQLITE_OK))
	{
		ERR << sql << msg << endl;
		sqlite3_free(msg);
		throw runtime_error(FAIL_STR("sql exec failed."));
	}
}

// 別のクラスにしたい
int SqliteWrapper::prepare(const std::string& sql)
{
	sqlite3_stmt* stmt;

	// prepare, length=-1ならNULL文字検索, 最後のNULLはパース完了箇所が欲しければ
	int ret = sqlite3_prepare_v2(db_, sql.c_str(), static_cast<int>(sql.length()), &stmt, NULL);
	if (FAIL(ret == SQLITE_OK))
	{
		ERR << "prepare error:" << sqlite3_errmsg(db_) << endl;
		throw runtime_error("SQL prepare failed.");
	}
	//
	stmts_.push_back(stmt);
	return static_cast<int>(stmts_.size()) - 1;
}

void SqliteWrapper::reset(int stmt_ix)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	sqlite3_reset(stmts_[stmt_ix]);
}

int SqliteWrapper::step(int stmt_ix)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}

	// SQLITE_ERROR：クエリが何らかの理由によりエラーとなった場合
	// SQLITE_ROW : クエリの結果が列として取れる場合
	// SQLITE_BUSY : クエリが未完の場合
	// SQLITE_DONE : クエリが完了時
	int ret;
	for (int i = 0; i<10000; i++)
	{
		ret = sqlite3_step(stmts_[stmt_ix]);
		if (ret == SQLITE_DONE)
		{
			break;
		}
		else if (ret == SQLITE_ROW)
		{
			break;
		}
		else if (ret == SQLITE_BUSY)
		{
			cout << "busy" << endl;
		}
		else
		{
			ERR << "unknown result in sqlite3_step" << ret << endl;
			throw runtime_error(FAIL_STR("sql step error."));
		}
	}
	return ret;
}

void SqliteWrapper::bind_int(int stmt_ix, int sql_ix, int value)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	sqlite3_bind_int(stmts_[stmt_ix], sql_ix, value);
}

void SqliteWrapper::bind_text(int stmt_ix, int sql_ix, const std::string &text)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	sqlite3_bind_text(stmts_[stmt_ix], sql_ix,
		text.c_str(), static_cast<int>(text.length()), SQLITE_TRANSIENT);
}

void SqliteWrapper::bind_real(int stmt_ix, int sql_ix, double value)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	sqlite3_bind_double(stmts_[stmt_ix], sql_ix, value);
}

void SqliteWrapper::bind_blob(int stmt_ix, int sql_ix,
	const void* blob, int size, void(*destructor)(void*))
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	sqlite3_bind_blob(stmts_[stmt_ix], sql_ix,
		blob, size, destructor);
}

int SqliteWrapper::column_count(int stmt_ix)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return sqlite3_column_count(stmts_[stmt_ix]);
}

std::string SqliteWrapper::column_name(int stmt_ix, int colmun)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return sqlite3_column_name(stmts_[stmt_ix], colmun);
}

int SqliteWrapper::column_type(int stmt_ix, int column)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return sqlite3_column_type(stmts_[stmt_ix], column);
}

int SqliteWrapper::column_int(int stmt_ix, int column)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return sqlite3_column_int(stmts_[stmt_ix], column);
}

std::string SqliteWrapper::column_text(int stmt_ix, int column)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return reinterpret_cast<const char*>(
		sqlite3_column_text(stmts_[stmt_ix], column));
}

double SqliteWrapper::column_real(int stmt_ix, int column)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return sqlite3_column_double(stmts_[stmt_ix], column);
}

const void* SqliteWrapper::column_blob(int stmt_ix, int column)
{
	if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
	{
		ERR << "unprepared index, [" << stmt_ix << "]" << endl;
		throw runtime_error(FAIL_STR("unprepared index."));
	}
	return sqlite3_column_blob(stmts_[stmt_ix], column);
}

SqliteWrapper::SqliteWrapper(const std::string& filename)
{
	open(filename);
}

SqliteWrapper::~SqliteWrapper()
{
	close();
}

