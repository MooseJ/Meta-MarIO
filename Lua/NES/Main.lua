require "Constants"
require "Inputs"
require "NeuralNetwork"
require "Pools"
require "SaveStates"
require "Forms"
require "Timeout"
require "SQL"

function GoBackOneHalfLevel()
	if pool.half==true then
		pool.half=false
	elseif pool.netLevel>0 then
		pool.netLevel=pool.netLevel-1
		pool.half=true
	elseif pool.netWorld>0 then
		pool.netWorld=pool.netWorld-1
		pool.half=true
	else
		print("Starting at Level 1")
	end
	if pool.half==true then
		Filename = "Level" .. pool.netWorld+1 .. pool.netLevel+1 .. 5 ..".state"
	else
		Filename = "Level" .. pool.netWorld+1 .. pool.netLevel+1 ..".state"
	end
	Filename = "States/"..Filename
	ConstantFilename=Filename
	print(Filename)
end

function InitializeStats()
	local statsFile=io.open("Stats".. tostring(forms.getthreadNum()) .. ".csv" ,"w+")
	statsFile:write("Generation".. ","  .. "Max Fitness".. "," .. "Average Fitness" .. "," .. "World" .. "," .. "Level" .. "\n")
	statsFile:close()
end

function LoadFromFile()
	LoadedIndex=LoadedIndex+1
	print(LoadedIndex)
	if LoadedIndex>#LoadedSpecies or LoadedIndex==0 then
		LoadedIndex=1
		savestate.load(ConstantFilename)
		pool.landscape = {}
		RoundAmount=0
		emu.frameadvance()
		emu.frameadvance()
	print("Reload")
	end
	return LoadedSpecies[LoadedIndex],LoadedGenomes[LoadedIndex]
end

function GetRandomGenome()
	local tail=table.remove(RandomNumbers)
	return tail
end



function GenerateRandomNumbers()
	local RandomNums={}
	for slot=1,Population do
		table.insert(RandomNums,slot)
	end
	RandomNums=shuffle(RandomNums)
	return RandomNums
end

--http://gamebuildingtools.com/using-lua/shuffle-table-lua
function shuffle(t)
  local n = #t -- gets the length of the table 
  while n > 2 do -- only run if the table has more than 1 element
    local k = math.random(n) -- get a random number
    t[n], t[k] = t[k], t[n]
    n = n - 1
 end
 return t
end

function CollectStats()
	local statsFile=io.open("Stats".. tostring(forms.getthreadNum()) .. ".csv","a")
	statsFile:write(pool.generation .. ","  .. pool.maxFitness .. "," .. pool.generationAverageFitness .. "," .. pool.marioWorld .. "," .. pool.marioLevel .. "\n")
	statsFile:close()
end	

function FileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end


function GatherReward(probalisticGenome,probalisticSpecies)
	isDone=nextGenome(probalisticGenome,probalisticSpecies)
	if isDone ==1 then 
		mode=DEATH_ACTION
		GenomeAmount=0
		if tonumber(forms.getthreadNum())>0 then
			RandomNumbers=GenerateRandomNumbers()
			GenomeAmount=1
		end
	elseif isDone==2 then
		CollectStats()
		console.writeline("Generation " .. pool.generation .. " Completed")
		console.writeline("For World ".. pool.marioWorld+1 .. " Level ".. pool.marioLevel+1)
		console.writeline("Generation Best Fitness: ".. pool.maxGenerationFitness  .." Max Fitness: ".. pool.maxFitness)
		pool.maxGenerationFitness=0
		mode=GENERATION_OVER
		GenomeAmount=0
		if tonumber(forms.getthreadNum())>0 then
			GenomeNumbers=NumberGenomes()
			RandomNumbers=GenerateRandomNumbers()
			GenomeAmount=1
		end
	else
		GenomeAmount=GenomeAmount+1
		initializeRun()
		fitness=GeneticAlgorithmLoop(probalisticGenome)
		UpdateReward(fitness)
		mode=WAIT
		DummyRow()
		status=0
	end
end

function GeneticAlgorithmLoop(probalisticGenome)
	local Alive=true
	local GlobalFitness=0
	--getPositions()
	--NetPage=marioPage
	--RightmostPage=NetPage
	while Alive do
		--print(pool.currentFrame)
		local species = pool.species[pool.currentSpecies]
		local genome = species.genomes[pool.currentGenome]

		--Get Postion of Mario reading the Hex Bits
		getPositions()

        if FileExists("display.txt") then
			displayGenome(genome)
		end
		--Every 5 frames evaluate the current orgranism
		if pool.currentFrame%6 == 0 then
				evaluateCurrent()
		end

		

		--Sets the output to whatever the network chooses
		joypad.set(controller)

		
		--Refeshes Timeout
		if pool.currentFrame%4 == 0 then
			CallTimeoutFunctions()
		end



		--Subtract one time unit each loop
		timeout = timeout - 1

		--Each extra four frames give mario and extra bonus living amount
		local timeoutBonus = pool.currentFrame / 4
		--Timeout or Killed by Monster or Kiled by Falling
		--or pool.currentFrame>250
		if timeout + timeoutBonus <=0  or memory.readbyte(0x000E)==11 or memory.readbyte(0x00B5)>1  then
			Alive=false
			
			
			--If Dead
			local fitness = 0
			local fitnesscheck={}
			for slot=1,5 do
				fitnesscheck[slot]=0
			end
			genome.ran=true
			if forms.ischecked(RightmostFitness) then
				fitnesscheck[1] = tonumber(forms.gettext(RightmostAmount))*(rightmost - NetX)
				genome.rightmostFitness=fitnesscheck[1]
				if marioX> pool.maxFitness then
					pool.maxFitness=marioX
				end
				if marioX> pool.maxGenerationFitness then
					pool.maxGenerationFitness=marioX
				end
			end
			if forms.ischecked(ScoreFitness) then
				fitnesscheck[2] = fitness+tonumber(forms.gettext(ScoreAmount))*(marioScore - NetScore)
			end
			if forms.ischecked(NoveltyFitness) then
				fitnesscheck[3] = fitness +tonumber(forms.gettext(NoveltyAmount))*(CurrentNSFitness)
			end
			-- if (rightmost-NetX)>20 then
			-- 	fitnesscheck[4] = (NetX-leftmost)*2+(rightmost-NetX)*.5
			-- end
			-- if (rightmost-NetX)>20 then
			-- 	fitnesscheck[5] = (upmost - NetY)*3+(rightmost-NetX)*.25
			-- end

			table.sort(fitnesscheck)
			fitness=fitnesscheck[#fitnesscheck]


			if fitness == 0 then
				fitness = -1
			end

			if tonumber(forms.getthreadNum())~=-2 then
				LevelChange()
				LevelChangeHalfway()
			end
			--New Code for Super Meta
			if memory.readbyte(0x000E)==11 or memory.readbyte(0x00B5)>1 or memory.readbyte(0x0770)==0 then
				--fitness= fitness-20
				status=1
				Survivors={}
				clearJoypad()
				savestate.load(Filename)
				
				--NetPage=memory.readbyte(0x6D)

			end

			
			



			if fitness > genome.fitness then
				genome.fitness = fitness
			end


			if fitness <= 0 then
				GlobalFitness=-1
			elseif fitness>100 then 
				GlobalFitness=100
			else 
				GlobalFitness=fitness
			end


		end

		pool.currentFrame = pool.currentFrame + 1
		emu.frameadvance()
	end	
	return GlobalFitness
end


DEATH_WAIT,DEATH_ACTION,WAIT,ACTION,GENERATION_OVER = 0,1,2,3,4
mode=WAIT
NetPage=0


Open()
savestate.load(Filename) --load Level 1
FitnessBox(140,40,600,700) --Set Dimensions of GUI


GenomeAmount=0
status=0
z=0
Survivors={}
print("..Starting")
initializePool()
load=false
if FileExists("current.pool") then
	loadFile("current.pool")
	load=true
	console.writeline("Model Loaded")
	savestate.load(Filename)
else
	InitializeStats()
end
UpdateGenes(CollectGenes())
if load==false then
	DummyRow()
else
	DummyRowLoad()
end
if tonumber(forms.getthreadNum())==-1 then
	x=0
	client.speedmode(100)

end
if tonumber(forms.getthreadNum())==-2 then
	x=0
	client.speedmode(50)
	
end
if tonumber(forms.getthreadNum())>0 then
	GenomeNumbers=NumberGenomes()
	RandomNumbers=GenerateRandomNumbers()
	GenomeAmount=1
	local seed=os.time()
	math.randomseed(seed)
	for i=1,tonumber(forms.getthreadNum()) do math.random(5) end
end 
LoadedSpecies={}
LoadedGenomes={}
LoadedIndex=-1
if tonumber(forms.getthreadNum())==-2 then
	loadLevelFinish("replay.pool")
	GoBackOneHalfLevel()
	print(Filename)
	clearJoypad()
end
while true do
	if tonumber(forms.getthreadNum())==0 then
		if (mode~=DEATH_ACTION) and memory.readbyte(0x000E)==11 then    
		   --mode=DEATH_WAIT 
		end
		if mode==DEATH_ACTION then
			DummyRowDead()
			savestate.load(Filename)
			mode=WAIT
		end 
		if mode==GENERATION_OVER then
			DummyRowEnd()
			savestate.load(Filename)
			mode=WAIT
		end 
		if mode==DEATH_WAIT and emu.checktable()==false then
			EraseLastAction()
			DummyRowDead()
			savestate.load(Filename)
			mode=WAIT
		end 
	    if mode==WAIT and emu.checktable()==false then
	 		mode=ACTION
	 	end
	 	if mode==ACTION then
	 		local probalisticGenome=GatherGenomeNum() 
	 		local probalisticSpecies=GatherSpeciesNum() 
	 		-- print("Species: "..probalisticSpecies)
		  --   print("Genome: "..probalisticGenome)
	 		table.insert(Survivors,probalisticSpecies..","..probalisticGenome)
	 		GatherReward(probalisticGenome,probalisticSpecies)
	 	end
	elseif tonumber(forms.getthreadNum())>0 then --Random
		GenomeNumber=GetRandomGenome()
		local probalisticGenome=GenomeNumbers[GenomeNumber].genome
	 	local probalisticSpecies=GenomeNumbers[GenomeNumber].species
		table.insert(Survivors,probalisticSpecies..","..probalisticGenome)
	 	GatherReward(probalisticGenome,probalisticSpecies)
	elseif tonumber(forms.getthreadNum())==-2 then
		speciesNum,genomeNum=LoadFromFile()
		local probalisticSpecies = tonumber(speciesNum)
		local probalisticGenome = tonumber(genomeNum)
		print("Species: "..probalisticSpecies)
		print("Genome: "..probalisticGenome)
		GatherReward(probalisticGenome,probalisticSpecies)
 	else
	 	local species = pool.species[pool.currentSpecies]
		local genome = species.genomes[pool.currentGenome]
	 	if x%6 == 0 then
			evaluateCurrent()
		end
		displayGenome(genome)
		x=x+1
	end	
 	emu.frameadvance()
end