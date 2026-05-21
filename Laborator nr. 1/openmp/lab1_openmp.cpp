#include <omp.h>
#include <iostream> 
#include <cstdint>
#include <chrono>
#include <atomic>
#include <vector>
#include "sha256.h"


using namespace std;
int check_comandline_passed_arguments(int argc, char *argv[])
{
    char* app_name = argv[0];

    cout << "Count of arguments passed: " << argc << endl;

    if(argc == 1)
    {
        cout << "Call application " << app_name << " with arguments [difficulty] [threads optional]." << endl;
        cout << "Example:" << endl;
        cout << app_name << " 7 -- run with default thread list: 1, 2, 4, 8, 16, 32" << endl;
        cout << app_name << " 7 8 -- run only with 8 threads" << endl;

        exit(0);
    }

    if(argc > 3)
    {
        cout << "Incorrect arguments passed." << endl;
        cout << "Usage: " << app_name << " [difficulty] [threads optional]" << endl;
        exit(1);
    }

    return 0;
}


string solve_crypto_puzzle(
    const string& str, 
    uint puzzle_difficulty, 
    uint64_t start, 
    uint64_t step, 
    atomic<bool>& solution_found
)
{
    string nonce_needle(puzzle_difficulty, '0');

    SHA256 sha256;

    for(uint64_t i = start; i < UINT64_MAX; i += step)
    {
        if (solution_found.load()) {
            return "";
        }

        string solution_candidate = str + to_string(i);
        string hash_code = sha256(solution_candidate);
        
        if(hash_code.compare(0, puzzle_difficulty, nonce_needle) == 0)
        {
            solution_found.store(true);
            cout << "Thread " << omp_get_thread_num() << " found a solution: " << solution_candidate << endl;
            return solution_candidate;
        }
    }
    
    return "";
}
int main (int argc, char *argv[]) 
{
    check_comandline_passed_arguments(argc, argv);

    int difficulty = atoi(argv[1]);

    SHA256 sha256;
    const string message("Hello World");

    vector<int> thread_counts;

    if(argc == 3)
    {
        int num_threads = atoi(argv[2]);
        thread_counts.push_back(num_threads);
    }
    else
    {
        thread_counts = {1, 2, 4, 8, 16, 32};
    }

    cout << "Message:" << endl << message << endl;
    cout << "Hash:" << endl << sha256(message) << endl;
    cout << endl;

    cout << "Looking for nonce to solve crypto-puzzle with "
         << difficulty << " difficulty..." << endl;

    cout << "Results OpenMP:" << endl;
    cout << "---------------------------------------------" << endl << endl;

    for(int num_threads : thread_counts)
    {
        int total_threads, current_thread_id;

        atomic<bool> solution_found(false);
        string solution = "";

        auto t1 = chrono::steady_clock::now();

        #pragma omp parallel num_threads(num_threads) private(total_threads, current_thread_id) shared(solution_found, solution)
        {
            current_thread_id = omp_get_thread_num();
            total_threads = omp_get_num_threads();

            string thread_solution = solve_crypto_puzzle(
                message,
                difficulty,
                current_thread_id,
                total_threads,
                solution_found
            );

            if(thread_solution != "")
            {
                #pragma omp critical
                {
                    if(solution == "")
                    {
                        solution = thread_solution;
                    }
                }
            }
        }

        auto t2 = chrono::steady_clock::now();
        auto duration_milliseconds = chrono::duration_cast<chrono::milliseconds>(t2 - t1);

        cout << "Num threads: " << num_threads << endl;
        cout << "Time taken: " << duration_milliseconds.count()
             << " milliseconds" << endl;

        if(solution == "")
        {
            cout << "No solution found." << endl;
        }
        else
        {
            cout << "Solution: " << solution << endl;
            cout << "Hash: " << sha256(solution) << endl;
        }

        cout << "---------------------------------------------" << endl << endl;
    }

    return 0;
}