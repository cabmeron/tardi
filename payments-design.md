behavior_contract_payment_intent
{
	stripe_customer_id: reference
	time_created: timestamp
	is_active: bool
	charge_time: timestamp
	amount: int
}

behavior_contract
{
	user_id: str
	behavior_contract_tasks: Array[behavior_contract_task]	
	time_created: timestamp
}

behavior_contract_task
{
	time_created: timestamp
	name: str
	description: str
	time_due: timestamp
	parent_behavior_contract: reference
	is_complete: bool
}

behavior_contract_task_node
{
	id: str
	latidue: lat
	longitude: long
	radius: int
	name: str
	description: str
}

