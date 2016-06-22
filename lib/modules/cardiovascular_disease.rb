module Synthea
	module Modules
    class CardiovascularDisease < Synthea::Rules

      #estimate cardiovascular risk of developing coronary heart disease (CHD)
      #http://www.nhlbi.nih.gov/health-pro/guidelines/current/cholesterol-guidelines/quick-desk-reference-html/10-year-risk-framingham-table#men

      #Indices in the array correspond to these age ranges: 20-24, 25-29, 30-34 35-39, 40-44, 45-49,
      #50-54, 55-59, 60-64, 65-69, 70-74, 75-79
      age_chd = {
        'M' => [-9, -9, -9, -4, 0, 3, 6, 8, 10, 11, 12, 13],
        'F' => [-7, -7, -7, -3, 0, 3, 6, 8, 10, 12, 14, 16]
      }

      age_chol_chd = {
        'M' => [
          #<160, 160-199, 200-239, 240-279, >280
          [0, 4, 7, 9, 11], #20-29 years
          [0, 4, 7, 9, 11], #30-39 years
          [0, 3, 5, 6, 8], #40-49 years
          [0, 2, 3, 4, 5], #50-59 years
          [0, 1, 1, 2, 3], #60-69 years
          [0, 0, 0, 1, 1] #70-79 years
            
        ],
        'F' => [
          #<160, 160-199, 200-239, 240-279, >280
          [0, 4, 8, 11, 13], #20-29 years
          [0, 4, 8, 11, 13], #30-39 years
          [0, 3, 6, 8, 10], #40-49 years
          [0, 2, 4, 5, 7], #50-59 years
          [0, 1, 2, 3, 4], #60-69 years
          [0, 1, 1, 2, 2] #70-79 years
        ]
      }
  		age_smoke_chd = {
        #20-29, 30-39, 40-49, 50-59, 60-69, 70-79 age ranges
        'M' => [8, 8, 5, 3, 1, 1],
        'F' => [9, 9, 7, 4, 2, 1]
      }

  		hdl_lookup_chd = [2, 1, 0, -1] # <40, 40-49, 50-59, >60

      #true/false refers to whether or not blood pressure is treated
      sys_bp_chd = {
        'M' => [
          {true => 0, false => 0}, #<120
          {true => 1, false => 0}, #120-129
          {true => 2, false => 1}, #130-139
          {true => 2, false => 1}, #140-149
          {true => 2, false => 1}, #150-159
          {true => 3, false => 2} #>=160
        ],
        'F' => [
          {true => 0, false => 0}, #<120
          {true => 3, false => 1}, #120-129
          {true => 4, false => 2}, #130-139
          {true => 5, false => 3}, #140-149
          {true => 5, false => 3}, #150-159
          {true => 6, false => 4} #>=160
        ]
      }


  		#framingham point scores gives a 10-year risk
      risk_chd = {
        'M' => {
          -1 => 0.005, #'-1' represents all scores <0
          0 => 0.01,
          1 => 0.01,
          2 => 0.01,
          3 => 0.01,
          4 => 0.01,
          5 => 0.02,
          6 => 0.02,
          7 => 0.03,
          8 => 0.04,
          9 => 0.05,
          10 => 0.06,
          11 => 0.08,
          12 => 0.1,
          13 => 0.12,
          14 => 0.16,
          15 => 0.20,
          16 => 0.25,
          17 => 0.3 #'17' represents all scores >16
        },
        'F' => {
          8 => 0.005, #'8' represents all scores <9
          9 => 0.01,
          10 => 0.01,
          11 => 0.01,
          12 => 0.01,
          13 => 0.02,
          14 => 0.02,
          15 => 0.03,
          16 => 0.04,
          17 => 0.05,
          18 => 0.06,
          19 => 0.08,
          20 => 0.11,
          21 => 0.14,
          22 => 0.17,
          23 => 0.22,
          24 => 0.27,
          25 => 0.3 #'25' represents all scores >24
        }
      }
  		

      # 9/10 smokers start before age 18. We will use 16.
      #http://www.cdc.gov/tobacco/data_statistics/fact_sheets/youth_data/tobacco_use/
      rule :start_smoking, [:age], [:smoker] do |time, entity|
        if entity[:smoker].nil? && entity[:age] == 16
          rand < Synthea::Config.cardiovascular.smoker ? entity[:smoker] = true : entity[:smoker] = false
        end
      end

  		
      rule :calculate_cardio_risk, [:cholesterol, :HDL, :age, :gender, :blood_pressure, :smoker], [:coronary_heart_disease?] do |time, entity|
  			return if entity[:age].nil? || entity[:blood_pressure].nil? || entity[:gender].nil? || entity[:cholesterol].nil?
			  age = entity[:age]
        gender = entity[:gender]
  			cholesterol = entity[:cholesterol][:total]
  			hdl_level = entity[:cholesterol][:hdl]
  			blood_pressure = entity[:blood_pressure][0]
			  bp_treated = entity[:bp_treated?] || false
        #calculate which index in a lookup array a number corresponds to based on ranges in scoring
        short_age_range = [[(age - 20)/5,0].max,11].min
        long_age_range = [[(age - 20)/10,0].max,5].min
        chol_range = [[(age - 160)/40 + 1,0].max,4].min
        hdl_range = [[(age - 40)/10 + 1,0].max,3].min
        bp_range = [[(age - 120)/10 + 1,0].max,5].min
  			framingham_points = 0
        framingham_points += age_chd[gender][short_age_range]
        framingham_points += age_chol_chd[gender][long_age_range][chol_range]
        if entity[:smoker]
          framingham_points += age_smoke_chd[gender][long_age_range]
        end

  			framingham_points += hdl_lookup_chd[hdl_range]
        framingham_points += sys_bp_chd[gender][bp_range][bp_treated]
        #restrict lower and upper bound of framingham score
        gender_bounds = {'M' => {'low' => 0, 'high' => 17}, 'F' => {'low' => 8, 'high' => 25}}
        framingham_points = [[framingham_points,gender_bounds[gender]['low']].max, gender_bounds[gender]['high']].min

        risk = risk_chd[gender][framingham_points]
        entity[:cardio_risk] = Synthea::Rules.convert_risk_to_timestep(risk,3650)
  		end

  		rule :coronary_heart_disease?, [:calculate_cardio_risk], [:coronary_heart_disease] do |time, entity|
  			if !entity[:cardio_risk].nil? && entity[:coronary_heart_disease].nil? && rand < entity[:cardio_risk]
  				entity[:coronary_heart_disease] = true 
  				entity.events.create(time, :coronary_heart_disease, :coronary_heart_disease?, true)
  			end
  		end 

      #numbers are from appendix: http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1647098/pdf/amjph00262-0029.pdf
  		rule :coronary_heart_disease, [:coronary_heart_disease?], [:myocardial_infarction, :cardiac_arrest, :encounter, :death] do |time, entity|
  			if entity[:gender] && entity[:gender] == 'M'
          index = 0
  			else
          index = 1
  			end
        annual_risk = Synthea::Config.cardiovascular.chd.coronary_attack_risk[index]
        cardiac_event_chance = Synthea::Rules.convert_risk_to_timestep(annual_risk,365)
        if entity[:coronary_heart_disease] && rand < cardiac_event_chance
          if rand < Synthea::Config.cardiovascular.chd.mi_proportion
            entity.events.create(time, :myocardial_infarction, :coronary_heart_disease)
          else
            entity.events.create(time, :cardiac_arrest, :coronary_heart_disease)
          end
          #creates unprocessed emergency encounter. Will be processed at next time step.
          entity.events.create(time, :emergency_encounter, :coronary_heart_disease)
          Synthea::Modules::Encounters.emergency_visit(time, entity)
          survival_rate = Synthea::Config.cardiovascular.chd.survive
          #survival rate triples if a bystander is present
          survival_rate *= 3 if rand < Synthea::Config.cardiovascular.chd.bystander
        	if rand > survival_rate
  					entity[:is_alive] = false
  					entity.events.create(time, :death, :coronary_heart_disease, true)
  					Synthea::Modules::Lifecycle::Record.death(entity, time)
  				end
        end
  		end

      #chance of getting a sudden cardiac arrest without heart disease. (Most probable cardiac event w/o cause or history)
      rule :no_coronary_heart_disease, [:coronary_heart_disease?], [:cardiac_arrest, :death] do |time, entity|
        annual_risk = Synthea::Config.cardiovascular.sudden_cardiac_arrest.risk
        cardiac_event_chance = Synthea::Rules.convert_risk_to_timestep(annual_risk,365)
        if entity[:coronary_heart_disease].nil? && rand < cardiac_event_chance
          entity.events.create(time, :cardiac_arrest, :no_coronary_heart_disease)
          entity.events.create(time, :emergency_encounter, :no_coronary_heart_disease)
          Synthea::Modules::Encounters.emergency_visit(time, entity)
          survival_rate = 1 - Synthea::Config.cardiovascular.sudden_cardiac_arrest.death
          survival_rate *= 3 if rand < Synthea::Config.cardiovascular.chd.bystander
          annual_death_risk = 1 - survival_rate
          if rand < Synthea::Rules.convert_risk_to_timestep(annual_death_risk,365)
            entity[:is_alive] = false
            entity.events.create(time, :death, :no_coronary_heart_disease, true)
            Synthea::Modules::Lifecycle::Record.death(entity, time)
          end
        end
      end

      #-----------------------------------------------------------------------#

      #Framingham score system for calculating risk of stroke
      #https://www.framinghamheartstudy.org/risk-functions/stroke/stroke.php

      #The index for each range corresponds to the number of points

      #data for men is first array, women in second.
      age_stroke = [
        [(54..56), (57..59), (60..62), (63..65), (66..68), (69..72),
        (73..75), (76..78), (79..81), (82..84), (85..999)],

        [(54..56), (57..59), (60..62), (63..64), (65..67), (68..70),
        (71..73), (74..76), (77..78), (79..81), (82..999)]
      ]

      untreated_sys_bp_stroke = [
        [(0..105), (106..115), (116..125), (126..135), (136..145), (146..155),
        (156..165), (166..175), (176..185), (185..195), (196..205)],

        [(0..95), (95..106), (107..118), (119..130), (131..143), (144..155),
        (156..167), (168..180), (181..192), (193..204), (205..216)]
      ]

      treated_sys_bp_stroke = [
        [(0..105), (106..112), (113..117), (118..123), (124..129), (130..135),
        (136..142), (143..150), (151..161), (162..176), (177..205)],

        [(0..95), (95..106), (107..113), (114..119), (120..125), (126..131),
        (132..139), (140..148), (149..160), (161..204), (205..216)]
      ]

      ten_year_stroke_risk = {
        'M' => {
          0 => 0, 1 => 0.03, 2 => 0.03, 3 => 0.04, 4 => 0.04, 5 => 0.05, 6 => 0.05, 7 => 0.06, 8 => 0.07, 9 =>0.08, 10 => 0.1,
          11 => 0.11, 12 => 0.13, 13 => 0.15, 14 => 0.17, 15 => 0.2, 16 => 0.22, 17 => 0.26, 18 => 0.29, 19 => 0.33, 20 => 0.37,
          21 => 0.42, 22 => 0.47, 23 => 0.52, 24 => 0.57, 25 => 0.63, 26 => 0.68, 27 => 0.74, 28 => 0.79, 29 => 0.84, 30 => 0.88
        },

        'F' => {
          0 => 0, 1 => 0.01, 2 => 0.01, 3 => 0.02, 4 => 0.02, 5 => 0.02, 6 => 0.03, 7 => 0.04, 8 => 0.04, 9 =>0.05, 10 => 0.06,
          11 => 0.08, 12 => 0.09, 13 => 0.11, 14 => 0.13, 15 => 0.16, 16 => 0.19, 17 => 0.23, 18 => 0.27, 19 => 0.32, 20 => 0.37,
          21 => 0.43, 22 => 0.5, 23 => 0.57, 24 => 0.64, 25 => 0.71, 26 => 0.78, 27 => 0.84
        }
      }

      diabetes_stroke = {'M' => 2,'F' => 3}
      chd_stroke_points = {'M' => 4, 'F' => 2}
      atrial_fibrillation_stroke_points = {'M' => 4, 'F' => 6}

      rule :calculate_stroke_risk, [:age, :diabetes, :coronary_heart_disease, :blood_pressure, :stroke_history, :smoker], [:stroke_risk] do |time, entity|
        return if entity[:age].nil? || entity[:blood_pressure].nil? || entity[:gender].nil? 
        age = entity[:age]
        gender = entity[:gender]
        blood_pressure = entity[:blood_pressure][0]
        #https://www.heart.org/idc/groups/heart-public/@wcm/@sop/@smd/documents/downloadable/ucm_449858.pdf
        #calculate stroke risk based off of prevalence of stroke in age group for people younger than 54. Framingham score system does not cover these.
        
        if gender == 'M'
          gender_index = 0
        else
          gender_index = 1
        end

        case
        when age < 20
          return
        when age < 40 && age >= 20
          rate = Synthea::Config.cardiovascular.stroke.rate_20_39[gender_index]
        when age < 55 && age >=40
          rate = Synthea::Config.cardiovascular.stroke.rate_40_59[gender_index]
        end

        if rate
          entity[:stroke_risk] = Synthea::Rules.convert_risk_to_timestep(rate, 3650) 
          return
        end

        stroke_points = 0
        stroke_points += 3 if entity[:smoker]
        stroke_points += 5 if entity[:left_ventricular_hypertrophy]
        stroke_points += age_stroke[gender_index].find_index{|range| range.include?(age)}
        if entity[:bp_treated?] #treating blood pressure currently is not a feature. Modify this for when it is.
          stroke_points += treated_sys_bp_stroke[gender_index].find_index{|range| range.include?(blood_pressure)}
        else 
          stroke_points += untreated_sys_bp_stroke[gender_index].find_index{|range| range.include?(blood_pressure)}
        end
        stroke_points += diabetes_stroke[gender] if entity[:diabetes]
        stroke_points += chd_stroke_points[gender] if entity[:coronary_heart_disease]
        stroke_points += atrial_fibrillation_stroke_points[gender] if entity[:atrial_fibrillation]
        ten_stroke_risk = ten_year_stroke_risk[gender][stroke_points]
        binding.pry if ten_stroke_risk.nil?

        #divide 10 year risk by 365 * 10 to get daily risk.
        entity[:stroke_risk] = Synthea::Rules.convert_risk_to_timestep(ten_stroke_risk, 3650)
        entity[:stroke_points] = stroke_points
      end

      rule :get_stroke, [:stroke_risk, :stroke_history], [:stroke, :death, :stroke_history] do |time, entity|
        if entity[:stroke_risk] && rand < entity[:stroke_risk]
          entity.events.create(time, :stroke, :get_stroke)
          entity[:stroke_history] = true
          entity.events.create(time + 10.minutes, :emergency_encounter, :get_stroke)
          Synthea::Modules::Encounters.emergency_visit(time + 15.minutes, entity)
          if rand < Synthea::Config.cardiovascular.stroke.death
            entity[:is_alive] = false
            entity.events.create(time, :death, :get_stroke, true)
            Synthea::Modules::Lifecycle::Record.death(entity, time)
          end
        end
      end

      #-----------------------------------------------------------------------#

      class Record < BaseRecord
        def self.perform_encounter(entity, time)
          [:coronary_heart_disease].each do |diagnosis|
            if entity[diagnosis] && !entity.record_conditions[diagnosis]
              entity.record_conditions[diagnosis] = Condition.new(condition_hash(diagnosis, time))
              entity.record.conditions << entity.record_conditions[diagnosis]
              
              entry = FHIR::Bundle::Entry.new
              entry.resource = create_fhir_condition(diagnosis, entity, time)
              entity.fhir_record.entry << entry
            end
          end
        end

        def self.perform_emergency(entity, event)
          time = event.time
          diagnosis = event.type
          if [:myocardial_infarction, :stroke, :cardiac_arrest].include?(diagnosis) && !entity.record_conditions[diagnosis]
            entity.record_conditions[diagnosis] = Condition.new(condition_hash(diagnosis, time))
            entity.record.conditions << entity.record_conditions[diagnosis]
        
            
            entry = FHIR::Bundle::Entry.new
            entry.resource = create_fhir_condition(diagnosis, entity, time)
            entity.fhir_record.entry << entry
          end
          #record treatments for coronary attack?
        end

        def self.create_fhir_condition(diagnosis, entity, time)
          patient = entity.fhir_record.entry.find{|e| e.resource.is_a?(FHIR::Patient)}
          conditionData = condition_hash(diagnosis, time)
          encounter = entity.fhir_record.entry.reverse.find {|e| e.resource.is_a?(FHIR::Encounter)}
          condition = FHIR::Condition.new({
            'id' => SecureRandom.uuid,
            'patient' => {'reference'=>"Patient/#{patient.fullUrl}"},
            'code' => {
              'coding'=>[{
                'code'=>conditionData['codes']['SNOMED-CT'][0],
                'display'=>conditionData['description'],
                'system' => 'http://snomed.info/sct'
              }],
              'text'=>conditionData['description']
            },
            'verificationStatus' => 'confirmed',
            'onsetDateTime' => convertFhirDateTime(time,'time'),
            'encounter' => {'reference'=>"Encounter/#{encounter.fullUrl}"}
          })
        end
      end
    end
	end
end
