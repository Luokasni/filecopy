
CC       = gcc
CXX      = g++
CFLAGS   = -Wall -Wextra -std=gnu11 -O2 -pthread -Iinclude
CXXFLAGS = -Wall -Wextra -std=c++14 -O2 -pthread -Iinclude
LDFLAGS  = -pthread

BUILD_DIR = build
TEST_DIR  = tests

# Application source files
SRC_FILES = src/copy.c \
            src/parallel.c \
            src/dir.c \
            src/queue.c \
            src/utils.c \
            src/log.c

MAIN_SRC = src/main.c

# Object files for the application and tests
OBJ_FILES = $(patsubst src/%.c,$(BUILD_DIR)/%.o,$(SRC_FILES))

.PHONY: all clean test gtest cppcheck misra analyze

all: $(BUILD_DIR)/mycp

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: src/%.c include/mycp.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/main.o: $(MAIN_SRC) include/mycp.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/mycp: $(OBJ_FILES) $(BUILD_DIR)/main.o
	$(CC) $^ $(LDFLAGS) -o $@

# Plain C unit tests
$(TEST_DIR)/test_mycp: $(TEST_DIR)/test_mycp.c $(OBJ_FILES)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

test: $(TEST_DIR)/test_mycp
	./$(TEST_DIR)/test_mycp

# Google Test
gtest: $(OBJ_FILES) $(TEST_DIR)/gtest_mycp.cpp
	$(CXX) $(CXXFLAGS) $(TEST_DIR)/gtest_mycp.cpp $(OBJ_FILES) \
		-lgtest -pthread -o $(TEST_DIR)/gtest_mycp
	./$(TEST_DIR)/gtest_mycp

# Static analysis
cppcheck:
	bash tests/run_cppcheck.sh cppcheck

misra:
	bash tests/run_cppcheck.sh misra

analyze: cppcheck misra

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(TEST_DIR)/test_mycp
	rm -f $(TEST_DIR)/gtest_mycp
