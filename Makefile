CC       = gcc
CXX      = g++
CFLAGS   = -Wall -Wextra -std=gnu11 -O2 -pthread
CXXFLAGS = -Wall -Wextra -std=c++14 -O2 -pthread
LDFLAGS  = -pthread

LIB_OBJS = copy.o parallel.o dir.o queue.o utils.o log.o
OBJS     = main.o $(LIB_OBJS)
TARGET   = mycp
TEST_C   = tests/test_mycp
TEST_GT  = tests/gtest_mycp
GTEST_LIBS = $(shell pkg-config --cflags --libs gtest_main 2>/dev/null || echo -lgtest_main -lgtest)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

%.o: %.c mycp.h
	$(CC) $(CFLAGS) -c $< -o $@

# ---- tests ------------------------------------------------------------
# plain C unit tests
$(TEST_C): tests/test_mycp.c $(LIB_OBJS) mycp.h
	$(CC) $(CFLAGS) -I. -o $@ tests/test_mycp.c $(LIB_OBJS) $(LDFLAGS)

# Google Test.
#   normal:        needs the installed library (sudo apt-get install -y libgtest-dev)
#   no install:    make gtest GTEST_SRC=/path/to/googletest   (folder that contains
#                  googletest/src/gtest-all.cc, e.g. /usr/src/googletest or a
#                  downloaded copy). The library is then compiled together with the
#                  tests, so headers and library can never be mismatched.
ifdef GTEST_SRC
GTEST_LIBS = -I$(GTEST_SRC)/googletest/include -I$(GTEST_SRC)/googletest \
             $(GTEST_SRC)/googletest/src/gtest-all.cc $(GTEST_SRC)/googletest/src/gtest_main.cc
endif
$(TEST_GT): tests/gtest_mycp.cpp $(LIB_OBJS) mycp.h
	$(CXX) $(CXXFLAGS) -I. -o $@ tests/gtest_mycp.cpp $(LIB_OBJS) $(GTEST_LIBS) $(LDFLAGS)

# C unit tests + command-line tests
test: $(TARGET) $(TEST_C)
	./$(TEST_C)
	bash tests/test_cli.sh

# Google Test suite
gtest: $(TEST_GT)
	./$(TEST_GT)

# memory-leak / memory-error check with Valgrind (needs: sudo apt-get install -y valgrind)
valgrind: $(TARGET) $(TEST_C)
	bash tests/run_valgrind.sh

# code coverage with gcov/lcov (needs: sudo apt-get install -y lcov libgtest-dev)
coverage:
	bash tests/run_coverage.sh

clean:
	rm -f $(OBJS) $(TARGET) $(TEST_C) $(TEST_GT)
	rm -rf cov
	rm -f *.gcda *.gcno *.gcov

.PHONY: all test gtest valgrind coverage clean