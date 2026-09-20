export const monkeysGrammar = {
	name: 'monkeys',
	scopeName: 'source.monkeys',
	patterns: [
		{ name: 'comment.line.number-sign.monkeys', match: '#.*$' },
		{ name: 'keyword.control.namespace.monkeys', match: '^\\+[A-Za-z0-9_.-]+' },
		{ name: 'entity.name.tag.profile.monkeys', match: '^@([A-Za-z0-9_.-]+(,[A-Za-z0-9_.-]+)*)?$' },
		{
			match: '^([A-Za-z_][A-Za-z0-9_]*)(=)(.*)$',
			captures: {
				'1': { name: 'variable.other.constant.monkeys' },
				'2': { name: 'keyword.operator.assignment.monkeys' },
				'3': { name: 'string.unquoted.monkeys' }
			}
		},
		{ name: 'variable.other.constant.monkeys', match: '^[A-Za-z_][A-Za-z0-9_]*' }
	],
	repository: {}
};
