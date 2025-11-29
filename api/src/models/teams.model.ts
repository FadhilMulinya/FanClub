import { Document, Schema, model } from 'mongoose';

// Keep broad types on the stats object so we can store the full API response
export interface ITeamStats {
	league?: any;
	team?: {
		id: number;
		name: string;
		logo?: string;
	};
	form?: string;
	fixtures?: any;
	goals?: any;
	clean_sheet?: {
		home?: number;
		away?: number;
		total?: number;
	};
	failed_to_score?: { total?: number };
	penalty?: any;
	[key: string]: any;
}

export interface ITeam extends Document {
	teamId: number;
	name: string;
	logo?: string;
	leagueId?: number;
	season?: number;
	stats: ITeamStats;
	createdAt: Date;
	updatedAt: Date;
}

const TeamStatsSchema = new Schema<ITeamStats>(
	{
		league: { type: Schema.Types.Mixed, default: {} },
		team: { type: Schema.Types.Mixed, default: {} },
		form: { type: String, default: '' },
		fixtures: { type: Schema.Types.Mixed, default: {} },
		goals: { type: Schema.Types.Mixed, default: {} },
		clean_sheet: { type: Schema.Types.Mixed, default: {} },
		failed_to_score: { type: Schema.Types.Mixed, default: {} },
		penalty: { type: Schema.Types.Mixed, default: {} },
	},
	{ _id: false }
);

const TeamSchema = new Schema<ITeam>(
	{
		teamId: { type: Number, required: true, unique: true, index: true },
		name: { type: String, required: true },
		logo: { type: String, required: false },
		leagueId: { type: Number, required: false },
		season: { type: Number, required: false },
		stats: { type: TeamStatsSchema, required: false },
	},
	{ timestamps: true }
);

const Team = model<ITeam>('Team', TeamSchema);
export default Team;
