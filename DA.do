//----------------------------------------------------------------------------//
// Deferred Acceptance algorithm
// Author: Alberto Antonello
// Date: 2025
// Description: This script defines a mata function to implement the 
//		student-proposing Deferred Acceptance algorithm.
//----------------------------------------------------------------------------//


/*
*The following code generates a toy dataset to validate the student_DA() function

clear all

set seed 12345

local n_id = 3
local list_len_max = 5

local n_obs = `n_id' * `list_len_max'

set obs `n_obs'

gen id = ceil(_n / `list_len_max')

drop if runiform() > 0.7
gen list_len = .
bysort id: replace list_len = _N

bysort id: gen prog_num = _n

gen rand1 = runiform()
bysort id (rand1): gen rank = _n
drop rand1

gen prior = runiform() < 0.5

gen prior_1 = prior
replace prior_1 = . if rank != 1

gen rand2 = runiform() if prog_num == 1
egen lottery_STB = rank(rand2)
bysort id (prog_num): replace lottery_STB = lottery_STB[_n-1] if _n > 1
drop rand2

gen rand3 = runiform()
bysort prog_num: egen lottery_MTB = rank(rand3)
drop rand3

gen school_cap = 1

gen female = 1
*/


//----------------------------------------------------------------------------//


capture mata mata drop student_DA() // Replace existent function

*Define function
mata:
void student_DA( // Initialize new function
    real colvector long_students,
    real colvector long_schools,
    real colvector long_rank,
    real colvector long_priorities,
    real colvector long_lot_nums,
    real colvector long_capacities,
    real colvector condition_mask,
    string scalar outvarname
)
{
    // Retrieve data from inputs -----------------------------------------//
	
	real scalar i,s,k // Define loop vars
	
	real colvector selected_idx
	selected_idx = selectindex(condition_mask :== 1) // Subset data according to the condition mask
    
    long_students     = long_students[selected_idx]
    long_schools      = long_schools[selected_idx]
    long_rank         = long_rank[selected_idx]
    long_priorities   = long_priorities[selected_idx]
    long_lot_nums     = long_lot_nums[selected_idx]
    long_capacities   = long_capacities[selected_idx]

	real colvector unique_students
	unique_students = uniqrows(long_students) // List of students
		
	real scalar N
	N = rows(unique_students) // # of students
		
	real colvector unique_schools
	unique_schools  = uniqrows(long_schools) // List of schools (programs)
		
	real scalar S
	S = rows(unique_schools) // # of schools (programs)
		
	real scalar NS
	NS = rows(long_students) // Total # of applications (submitted student-program pairs)
		
	real colvector capacities
	capacities = J(S, 1, 0)
	for (s = 1; s <= S; s++) {
		capacities[s] = max(select(long_capacities, long_schools :== unique_schools[s])) // List of programs' capacities
	}
		
		
	// Initialize vectors ------------------------------------------------//
		
	real colvector effective_lot_nums
	effective_lot_nums = long_lot_nums :- 10000 :* (long_priorities :== 1)
	// Generate a list of effective lottery numbers by substracting 10,000 to the original lottery number when student has priority at a school
		
	real colvector next_program_rank
	next_program_rank = J(N, 1, 1)
	// Initialize vector that stores the rank of the program to which a student will apply in the next round
	// A negative integer will be stored in this vector if a student does not apply to any program in the next round
	// This may happen either because that student is currently "on a leash" or when they have run out of programs to apply for, according to their ROLs
	// In the first case, the absolute value of that negative integer stores the last rank the student has applied for (up the current round)
	// In the second case, the stored integer is set to -99
		
	real colvector on_leash
	on_leash = J(NS, 1, 0) // Initialize vector that stores student-program pairs currently "on a leash"
		
		
	// Run algorithm -----------------------------------------------------//
		
	for(k = 1; any(next_program_rank :> 0); k++) { // Loop over rounds
		// First, replace elements of vector on_leash with 1s if student proposes
		// In this way, vector on_leash temporarily flags both new applications and students "on a leash" (at the end of last round)
		for (i = 1; i <= N; i++) {
			if (next_program_rank[i] :> 0) { // Student proposes to a program only if their entry of vector next_program_rank is positive (see explanation above)
				on_leash[selectindex((long_students :== unique_students[i]) :& (long_rank :== next_program_rank[i]))] = 1
			}
		}
			
		// Now, every school evaluates its pending proposals (including past proposals "on a leash"), and runs lotteries if necessary (# pending proposals > capacity)
		// Loop over schools/programs
		for (s = 1; s <= S; s++) {
			real colvector mask
			mask = (long_schools :== unique_schools[s]) :& (on_leash :== 1) // Flag cells with pending proposals for school s
				
			if (sum(mask) > 0) { // Schools may have no applicants in some rounds
				if (capacities[s] == 0) { // In 2021, some programs ("kansrijk") have zero capacity
					continue // Skip schools with 0 capacity
				}
				
				real colvector lot_slice
				lot_slice = effective_lot_nums[selectindex(mask)] // Retrieve lottery numbers of pending proposals
					
				real colvector lot_ranks
				lot_ranks = order(lot_slice, 1) // Rank lottery numbers
					
				real colvector on_leash_update
				on_leash_update = J(rows(lot_slice), 1, 0) // Initialize a vector to update on_leash
					
				if (rows(on_leash_update) :<= capacities[s]) { // If all pending proposal can be accommodated, they are all placed "on a leash"
					on_leash_update = J(rows(lot_slice), 1, 1)
				} else { // If some of the pending proposals cannot be accommodated, those with lowest lottery numbers are placed "on a leash", the others are discarded
					on_leash_update[lot_ranks[1..capacities[s]]] = J(capacities[s], 1, 1)
				}
					
				on_leash[selectindex(mask)] = on_leash_update // Update vector on_leash
			}
		}
			
		// Finally, we update vector next_program_rank
		// Loop over students
		for (i = 1; i <= N; i++) {
			if (sum(on_leash[selectindex(long_students :== unique_students[i])]) == 0) { // If student is NOT on a leash at the end of the round...
				if (sum((long_students :== unique_students[i]) :& (long_rank :== abs(next_program_rank[i]) + 1)) > 0) { // Check if the student has a school at the next rank
					next_program_rank[i] = abs(next_program_rank[i]) + 1 // If so, update next_program_rank
				} else { // If student has run out of schools to applied for, then set next rank to -99
					next_program_rank[i] = -99
				}

			} else { // If student is on a leash at the end of the round...
				next_program_rank[i] = -abs(next_program_rank[i]) // Mark as negative
				// This allows to flag that student is on a leash (so that they do not propose on the next round) without losing information on the last rank they applied for
			}
		}
	}
	printf("Algorithm finished after %g rounds.\n", k - 1)
		
		
	// Store results in a new var ----------------------------------------//
	
	real colvector long_placement
	long_placement = J(NS, 1, .) // Initialize placement vector
		
	// Fill vector with allocations determined by the algorithm
	// Loop over students
	for (i = 1; i <= N; i++) {
		real colvector mask_2
		mask_2 = ((long_students :== unique_students[i]) :& (on_leash :== 1)) // Retrieve students on a leash at the end of the final round of the algorithm
			
		if (sum(mask_2) > 0) { // Students might have been left unassigned by the algorithm
			long_placement[selectindex(long_students :== unique_students[i])] = J(rows(selectindex(long_students :== unique_students[i])), 1, long_schools[selectindex(mask_2)])
			// Fill vector with final placements
		}
	}

    real colvector full_placement
	full_placement = J(rows(condition_mask), 1, .)
    full_placement[selected_idx] = long_placement // Prepare final vector of same length as original dataset

    st_addvar("double", outvarname)
    st_store(., outvarname, full_placement) // Store results in dataset
}

mata mosave student_DA(), replace // Save .mo file

end


//----------------------------------------------------------------------------//


*Apply function to toy dataset
//gen byte mask = (female == 1)
//mata student_DA(st_data(., "id"), st_data(., "prog_num"), st_data(., "rank"), st_data(., "prior"), st_data(., "lottery_STB"), st_data(., "school_cap"), st_data(., "mask"), "placement_alg")


//----------------------------------------------------------------------------//

