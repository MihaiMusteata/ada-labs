#include "sha256.h"
#include <iostream> 
#include <cstdint>
#include <chrono>

using namespace std;

string solve_crypto_puzzle(string str, uint puzzle_difficulty)
{
    string nonce_needle(puzzle_difficulty, '0');

    SHA256 sha256;
    for(uint64_t i=0; i < UINT64_MAX; i++){
        string solution_candidate = str + to_string(i);
        string hash_code = sha256(solution_candidate);

        if(hash_code.compare(0, puzzle_difficulty, nonce_needle) == 0){
            return solution_candidate;
        }
    }
    throw "No result found";
}

int check_comandline_passed_arguments(int argc, char *argv[])
{
    char* app_name = argv[0];
    if(argc == 1){
        cout << "Call application "<< app_name << " with arguments [n]." << endl;
        cout << "Example:" << endl;
        cout << app_name <<" 7 -- Application will try to solve crypto puzzle SHA256 with nonce that will generate 7 trailing 0 of the hashed message." << endl;
        cout << app_name <<" 8 -- Application will try to solve crypto puzzle SHA256 with nonce that will generate 8 trailing 0 of the hashed message." << endl;

        exit(0);
    }
    if(argc > 2)
    {
        cout << "Incorrect arguments passed." << endl;
        cout << "Call application "<< app_name << " for help message" << endl;
        exit(1);
    }
    return 0;
}

int main(int argc, char *argv[])
{
    check_comandline_passed_arguments(argc, argv);

    int difficulty = atoi(argv[1]);
    SHA256 sha256;
    const string message("Hello World");

    cout << "Message:" << endl << message << endl;
    cout << "Hash:" << endl << sha256(message) << endl;
    cout << endl << endl;
    cout << "Looking for nonce to solve crypto-puzzle with level " << difficulty << " difficulty" << "..." << endl;
    auto t1 = chrono::high_resolution_clock::now();
    try
    {
        auto solution = solve_crypto_puzzle(message, difficulty);

        cout << "Solution: " << endl << solution << endl;
        cout << "Hash:" << endl << sha256(solution) << endl;
    }
    catch(const char* msg)
    {
        cout << msg << endl;
    }

    auto t2 = chrono::high_resolution_clock::now();
    auto duration_milliseconds = chrono::duration_cast<chrono::milliseconds>(t2 - t1);

    cout << duration_milliseconds.count() << " milliseconds\n";
}
