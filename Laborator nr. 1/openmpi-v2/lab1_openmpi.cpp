#include <mpi.h>
#include "sha256.h"
#include <iostream>
#include <cstdint>

using namespace std;

int check_comandline_passed_arguments(int argc, char *argv[], int world_rank)
{
    char* app_name = argv[0];

    if(argc == 1)
    {
        if(world_rank == 0)
        {
            cout << "Call application " << app_name << " with arguments [n]." << endl;
            cout << "Example:" << endl;
            cout << app_name << " 7 -- Application will try to solve crypto puzzle SHA256 with nonce that will generate 7 leading 0 of the hashed message." << endl;
            cout << app_name << " 8 -- Application will try to solve crypto puzzle SHA256 with nonce that will generate 8 leading 0 of the hashed message." << endl;
        }

        return 1;
    }

    if(argc > 2)
    {
        if(world_rank == 0)
        {
            cout << "Incorrect arguments passed." << endl;
            cout << "Call application " << app_name << " for help message" << endl;
        }

        return 1;
    }

    return 0;
}

string solve_crypto_puzzle(
    const string& str,
    uint puzzle_difficulty,
    int world_rank,
    int world_size,
    double start_time,
    double& found_time
)
{
    uint64_t start = world_rank;
    uint64_t step = world_size;

    string nonce_needle(puzzle_difficulty, '0');
    SHA256 sha256;

    const int STOP_TAG = 100;
    const uint64_t check_interval = 1000;

    uint64_t iterations = 0;

    for(uint64_t i = start; i < UINT64_MAX; i += step)
    {
        iterations++;

        if(iterations % check_interval == 0)
        {
            int flag = 0;

            MPI_Iprobe(
                MPI_ANY_SOURCE,
                STOP_TAG,
                MPI_COMM_WORLD,
                &flag,
                MPI_STATUS_IGNORE
            );

            if(flag)
            {
                int stop_signal;

                MPI_Recv(
                    &stop_signal,
                    1,
                    MPI_INT,
                    MPI_ANY_SOURCE,
                    STOP_TAG,
                    MPI_COMM_WORLD,
                    MPI_STATUS_IGNORE
                );

                return "";
            }
        }

        string solution_candidate = str + to_string(i);
        string hash_code = sha256(solution_candidate);

        if(hash_code.compare(0, puzzle_difficulty, nonce_needle) == 0)
        {
            found_time = MPI_Wtime() - start_time;

            int stop_signal = 1;

            for(int rank = 0; rank < world_size; rank++)
            {
                if(rank != world_rank)
                {
                    MPI_Send(
                        &stop_signal,
                        1,
                        MPI_INT,
                        rank,
                        STOP_TAG,
                        MPI_COMM_WORLD
                    );
                }
            }

            return solution_candidate;
        }
    }

    return "";
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    if(check_comandline_passed_arguments(argc, argv, world_rank) != 0)
    {
        MPI_Finalize();
        return 0;
    }

    int difficulty = atoi(argv[1]);

    SHA256 sha256;
    const string message("Hello World");

    if(world_rank == 0)
    {
        cout << "Message:" << endl << message << endl;
        cout << "Hash:" << endl << sha256(message) << endl;
        cout << endl << endl;
        cout << "Looking for nonce to solve crypto-puzzle with level "
             << difficulty << " difficulty..." << endl;
        cout << "MPI processes: " << world_size << endl;
    }

    MPI_Barrier(MPI_COMM_WORLD);

    double start_time = MPI_Wtime();
    double found_time = 0.0;

    string solution = solve_crypto_puzzle(
        message,
        difficulty,
        world_rank,
        world_size,
        start_time,
        found_time
    );

    if(!solution.empty())
    {
        cout << "Processor " << world_rank
             << " found a solution: " << solution << endl;
        cout << "Hash: " << sha256(solution) << endl;
        cout << "Time taken: " << found_time * 1000
             << " milliseconds" << endl;
    }

    MPI_Finalize();

    return 0;
}