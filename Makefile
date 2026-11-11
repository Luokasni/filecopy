
CC       = gcc
CXX      = g++
CFLAGS   = -Wall -Wextra -std=gnu11 -O2 -pthread
CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -pthread
LDFLAGS  = -pthread

INCLUDES = -Iinclude

LIB_OBJS = copy.o parallel.o dir.o queue.o utils.o log.o
OBJS     = main.o $(LIB_OBJS)

TARGET   = mycp
TEST_C   = tests/test_mycp
TEST_GT  = tests/gtest_mycp

GTEST_LIBS = $(shell pkg-config --cflags --libs gtest_main 2>/dev/null || echo -lgtest_main -lgtest)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

%.o: src/%.c include/mycp.h
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# ---- Tests ------------------------------------------------------------

$(TEST_C): tests/test_mycp.c $(LIB_OBJS) include/mycp.h
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ tests/test_mycp.c $(LIB_OBJS) $(LDFLAGS)

# Google Test configuration

ifneq ($(wildcard /usr/local/include/gtest/gtest.h),)
GTEST_LIBS = -I/usr/local/include -L/usr/local/lib64 -L/usr/local/lib \
             -Wl,-rpath,/usr/local/lib64 -Wl,-rpath,/usr/local/lib -lgtest_main -lgtest
endif

ifdef GTEST_SRC
GTEST_LIBS = -I$(GTEST_SRC)/googletest/include -I$(GTEST_SRC)/googletest \
             $(GTEST_SRC)/googletest/src/gtest-all.cc \
             $(GTEST_SRC)/googletest/src/gtest_main.cc
endif

$(TEST_GT): tests/gtest_mycp.cpp $(LIB_OBJS) include/mycp.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ tests/gtest_mycp.cpp $(LIB_OBJS) $(GTEST_LIBS) $(LDFLAGS)

test: $(TARGET) $(TEST_C)
	./$(TEST_C)
	bash tests/test_cli.sh

gtest: $(TEST_GT)
	./$(TEST_GT)

valgrind: $(TARGET) $(TEST_C)
	bash tests/run_valgrind.sh

coverage:
	bash tests/run_coverage.sh

clean:
	rm -f $(OBJS) $(TARGET) $(TEST_C) $(TEST_GT)
	rm -rf cov
	rm -f *.gcda *.gcno *.gcov

.PHONY: all test gtest valgrind coverage clean
